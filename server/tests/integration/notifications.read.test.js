import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let admin2;
let recepcion;
let mecanico;
let seq = 0;

const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

async function crearMantenimiento(dias) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `LEC-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 });
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  return createMaintenance(vehicle.id, orden.id, mecanico.id, { description: `Servicio ${seq}`, dueDate: hoyMas(dias) });
}

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));
const marcar = (user, keys) => request(app).post('/api/notifications/read').set(auth(user.token)).send({ keys });
const filas = async () => (await query('SELECT user_id, notice_key FROM notification_reads ORDER BY notice_key')).length;

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  admin2 = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('marcar avisos como leídos (US6, FR-006, FR-007)', () => {
  it('test_marcar_como_leido_persiste_y_baja_el_contador', async () => {
    const vencido = await crearMantenimiento(-5);
    await crearMantenimiento(-9);

    const res = await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ marked: 1, unread: 1 });
    const despues = await consultar(admin);
    expect(despues.body.data.unread).toBe(1);
    expect(despues.body.data.total).toBe(2);
    const item = despues.body.data.groups[0].items.find((i) => i.key === `MAINT_OVERDUE:${vencido.id}`);
    expect(item.read).toBe(true);
  });

  it('test_la_lectura_es_por_usuario', async () => {
    const vencido = await crearMantenimiento(-5);
    await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);

    const otro = await consultar(admin2);
    const recep = await consultar(recepcion);

    expect(otro.body.data.unread).toBe(1);
    expect(otro.body.data.groups[0].items[0].read).toBe(false);
    expect(recep.body.data.unread).toBe(1);
  });

  it('test_un_aviso_leido_cuya_condicion_deja_de_cumplirse_desaparece', async () => {
    const vencido = await crearMantenimiento(-5);
    await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);

    await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [vencido.id]);
    const res = await consultar(admin);

    expect(res.body.data.groups).toEqual([]);
    expect(res.body.data.unread).toBe(0);
  });

  it('test_de_proximo_a_vencido_reaparece_sin_leer_porque_la_clave_cambia', async () => {
    const mantenimiento = await crearMantenimiento(10);
    await marcar(admin, [`MAINT_UPCOMING:${mantenimiento.id}`]);
    expect((await consultar(admin)).body.data.unread).toBe(0);

    await query('UPDATE maintenance SET due_date = ? WHERE id = ?', [hoyMas(-2), mantenimiento.id]);
    const res = await consultar(admin);

    expect(res.body.data.groups.map((g) => g.type)).toEqual(['MAINT_OVERDUE']);
    expect(res.body.data.groups[0].items[0].key).toBe(`MAINT_OVERDUE:${mantenimiento.id}`);
    expect(res.body.data.groups[0].items[0].read).toBe(false);
    expect(res.body.data.unread).toBe(1);
  });

  it('test_las_claves_inexistentes_se_ignoran_sin_error', async () => {
    const vencido = await crearMantenimiento(-5);

    const res = await marcar(admin, ['MAINT_OVERDUE:99999', 'STOCK_LOW:5', `MAINT_OVERDUE:${vencido.id}`]);

    expect(res.status).toBe(200);
    expect(res.body.data.marked).toBe(1);
    expect(await filas()).toBe(1);
  });

  it('test_marcar_un_aviso_que_desaparecio_no_da_error', async () => {
    const vencido = await crearMantenimiento(-5);
    await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [vencido.id]);

    const res = await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ marked: 0, unread: 0 });
    expect(await filas()).toBe(0);
  });

  it('test_repetir_la_solicitud_no_falla_ni_duplica_filas', async () => {
    const vencido = await crearMantenimiento(-5);

    const uno = await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);
    const dos = await marcar(admin, [`MAINT_OVERDUE:${vencido.id}`]);

    expect(uno.status).toBe(200);
    expect(dos.status).toBe(200);
    expect(await filas()).toBe(1);
  });

  it('test_cinco_solicitudes_simultaneas_dejan_una_sola_fila', async () => {
    const vencido = await crearMantenimiento(-5);

    const respuestas = await Promise.all(Array.from({ length: 5 }, () => marcar(admin, [`MAINT_OVERDUE:${vencido.id}`])));

    for (const res of respuestas) expect(res.status).toBe(200);
    expect(await filas()).toBe(1);
  });

  it('test_marcar_varios_avisos_a_la_vez', async () => {
    const a = await crearMantenimiento(-5);
    const b = await crearMantenimiento(-9);
    const c = await crearMantenimiento(10);

    const res = await marcar(admin, [`MAINT_OVERDUE:${a.id}`, `MAINT_OVERDUE:${b.id}`, `MAINT_UPCOMING:${c.id}`]);

    expect(res.body.data).toEqual({ marked: 3, unread: 0 });
    expect(await filas()).toBe(3);
  });

  it('test_el_mecanico_no_puede_marcar_avisos_que_no_ve', async () => {
    const vencido = await crearMantenimiento(-5);

    const res = await marcar(mecanico, [`MAINT_OVERDUE:${vencido.id}`]);

    expect(res.status).toBe(200);
    expect(res.body.data.marked).toBe(0);
    expect(await filas()).toBe(0);
  });

  it('test_la_recepcion_no_puede_marcar_avisos_de_stock', async () => {
    const res = await marcar(recepcion, ['STOCK_LOW:1', 'STOCK_OUT:1']);

    expect(res.status).toBe(200);
    expect(res.body.data.marked).toBe(0);
    expect(await filas()).toBe(0);
  });

  it('test_los_avisos_pasados_del_limite_de_cincuenta_tambien_se_pueden_marcar', async () => {
    const creados = [];
    for (let i = 0; i < 52; i += 1) creados.push(await crearMantenimiento(-3));

    const ultimo = creados.at(-1);
    const antes = await consultar(admin);
    expect(antes.body.data.groups[0].items).toHaveLength(50);
    const res = await marcar(admin, [`MAINT_OVERDUE:${ultimo.id}`]);

    expect(res.body.data.marked).toBe(1);
    expect(res.body.data.unread).toBe(51);
  });
});
