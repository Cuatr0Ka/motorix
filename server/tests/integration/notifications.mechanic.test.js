import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createAppointment,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
  createOrder,
  createPart,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let otroMecanico;
let seq = 0;

const haceDias = (dias) => new Date(Date.now() - dias * 24 * 3600 * 1000);
const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

async function ordenDetenida({ mechanicId, cliente = 'Ana Torres', telefono = '7761234567', dias = 5 }) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle(
    { licensePlate: `MEC-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 },
    { name: cliente, phone: telefono },
  );
  const orden = await createOrder(vehicle.id, recepcion.id, { mechanicId, status: 'EN_REPARACION', entryMileage: 0 });
  await query('UPDATE order_status_history SET changed_at = ? WHERE order_id = ?', [haceDias(dias), orden.id]);
  return orden;
}

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
});

describe('el mecánico ve solo lo que le corresponde (US5, FR-004, FR-015)', () => {
  it('test_solo_recibe_las_ordenes_detenidas_que_tiene_asignadas', async () => {
    const mia = await ordenDetenida({ mechanicId: mecanico.id });
    await ordenDetenida({ mechanicId: otroMecanico.id });
    await ordenDetenida({ mechanicId: null });

    const res = await consultar(mecanico);

    expect(res.status).toBe(200);
    expect(res.body.data.groups.map((g) => g.type)).toEqual(['STALLED']);
    expect(res.body.data.total).toBe(1);
    expect(res.body.data.groups[0].items[0].target).toEqual({ kind: 'order', id: mia.id });
  });

  it('test_no_recibe_avisos_de_citas_mantenimientos_ni_stock_aunque_existan', async () => {
    await ordenDetenida({ mechanicId: mecanico.id });
    const { client, vehicle } = await createClientWithVehicle({ currentMileage: 1000 });
    const hoy = new Date();
    await createAppointment(client.id, vehicle.id, recepcion.id, {
      scheduledAt: new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 15),
    });
    const { vehicle: v2 } = await createClientWithVehicle({ licensePlate: 'MEC-999-Z', currentMileage: 1000 });
    const entregada = await createFinishedOrder(v2.id, admin.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
    await createMaintenance(v2.id, entregada.id, mecanico.id, { description: 'Vencido', dueDate: hoyMas(-5) });
    await createPart(admin.id, { stock: 0, minStock: 4 });

    const res = await consultar(mecanico);

    expect(res.body.data.groups.map((g) => g.type)).toEqual(['STALLED']);
    expect(JSON.stringify(res.body)).not.toMatch(/APPT_|MAINT_|STOCK_/);
  });

  it('test_los_avisos_no_traen_nombre_de_cliente_ni_telefono', async () => {
    await ordenDetenida({ mechanicId: mecanico.id, cliente: 'Ana Torres', telefono: '7761234567' });

    const res = await consultar(mecanico);

    const cuerpo = JSON.stringify(res.body);
    expect(cuerpo).not.toContain('Ana Torres');
    expect(cuerpo).not.toContain('7761234567');
    expect(cuerpo).not.toMatch(/phone|client/i);
    const aviso = res.body.data.groups[0].items[0];
    expect(aviso.detail).toContain(aviso.folio);
    expect(aviso.detail).toContain('En reparación');
    expect(aviso.detail).toMatch(/MEC-001-Z/);
  });

  it('test_marcar_claves_de_ordenes_ajenas_se_ignora', async () => {
    const ajena = await ordenDetenida({ mechanicId: otroMecanico.id });
    const claveAjena = (await consultar(admin)).body.data.groups[0].items.find((i) => i.target.id === ajena.id).key;

    const res = await request(app)
      .post('/api/notifications/read')
      .set(auth(mecanico.token))
      .send({ keys: [claveAjena] });

    expect(res.status).toBe(200);
    expect(res.body.data.marked).toBe(0);
    expect((await query('SELECT * FROM notification_reads')).length).toBe(0);
  });

  it('test_el_mecanico_marca_como_leido_un_aviso_de_su_orden', async () => {
    await ordenDetenida({ mechanicId: mecanico.id });
    const clave = (await consultar(mecanico)).body.data.groups[0].items[0].key;

    const res = await request(app).post('/api/notifications/read').set(auth(mecanico.token)).send({ keys: [clave] });

    expect(res.body.data).toEqual({ marked: 1, unread: 0 });
  });

  it('test_no_accede_a_la_lista_de_clientes_por_avisar_con_ninguna_ruta', async () => {
    const orden = await ordenDetenida({ mechanicId: mecanico.id });

    const lista = await request(app).get('/api/client-notices').set(auth(mecanico.token));
    const marca = await request(app)
      .post('/api/client-notices')
      .set(auth(mecanico.token))
      .send({ reason: 'ORDER_READY', factId: orden.id });

    expect(lista.status).toBe(403);
    expect(marca.status).toBe(403);
    expect(JSON.stringify(lista.body)).not.toMatch(/phone/i);
    expect((await query('SELECT * FROM client_notices')).length).toBe(0);
  });

  it('test_el_rol_vigente_en_la_base_decide_aunque_el_token_sea_el_de_otro_rol', async () => {
    await ordenDetenida({ mechanicId: otroMecanico.id });
    expect((await consultar(mecanico)).body.data.groups).toEqual([]);

    // La persona pasa de mecánico a administrador: con el mismo token ya ve las órdenes de todos.
    await query("UPDATE users SET role = 'ADMIN' WHERE id = ?", [mecanico.id]);
    const res = await consultar(mecanico);

    expect(res.body.data.total).toBe(1);
    expect(JSON.stringify(res.body)).toContain('Ana Torres');
  });

  it('test_sin_avisos_propios_recibe_una_respuesta_vacia', async () => {
    await ordenDetenida({ mechanicId: otroMecanico.id });

    const res = await consultar(mecanico);

    expect(res.body.data).toMatchObject({ unread: 0, total: 0, groups: [] });
  });
});
