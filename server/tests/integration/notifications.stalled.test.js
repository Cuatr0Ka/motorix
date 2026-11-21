import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let seq = 0;

const haceDias = (dias) => new Date(Date.now() - dias * 24 * 3600 * 1000);

/** Orden abierta con su historial envejecido `dias` días (el último cambio de estado fue hace ese tiempo). */
async function ordenDetenida({ status = 'ESPERANDO_REFACCION', dias = 4, cliente = 'Ana Torres', mechanicId = mecanico.id } = {}) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle(
    { licensePlate: `DET-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 },
    { name: cliente },
  );
  const orden = await createOrder(vehicle.id, recepcion.id, { mechanicId, status, entryMileage: 0 });
  await query('UPDATE order_status_history SET changed_at = ? WHERE order_id = ?', [haceDias(dias), orden.id]);
  return { ...orden, vehicle };
}

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));
const marcar = (user, keys) => request(app).post('/api/notifications/read').set(auth(user.token)).send({ keys });
const grupo = (res) => res.body.data.groups.find((g) => g.type === 'STALLED');
const ultimoHistorial = async (ordenId) =>
  (await query('SELECT id FROM order_status_history WHERE order_id = ? ORDER BY changed_at DESC, id DESC LIMIT 1', [ordenId]))[0].id;

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('avisos de órdenes detenidas (US4, D-01, FR-013)', () => {
  it('test_una_orden_abierta_con_cuatro_dias_sin_cambio_genera_aviso_con_los_datos_de_la_orden', async () => {
    const orden = await ordenDetenida({ dias: 4, cliente: 'Ana Torres' });

    const res = await consultar(admin);

    const aviso = grupo(res).items[0];
    expect(grupo(res).total).toBe(1);
    expect(aviso.key).toBe(`STALLED:${orden.id}:${await ultimoHistorial(orden.id)}`);
    expect(aviso.title).toBe('Orden detenida');
    expect(aviso.folio).toBe(`OS-${String(orden.id).padStart(6, '0')}`);
    expect(aviso.status).toBe('ESPERANDO_REFACCION');
    expect(aviso.daysStalled).toBe(4);
    expect(aviso.detail).toContain(aviso.folio);
    expect(aviso.detail).toContain('Ana Torres');
    expect(aviso.detail).toContain('Esperando refacción');
    expect(aviso.detail).toContain('4 días sin cambio');
    expect(aviso.target).toEqual({ kind: 'order', id: orden.id });
  });

  it('test_con_tres_dias_exactos_no_genera_aviso_y_con_cuatro_si', async () => {
    await ordenDetenida({ dias: 3 });
    expect((await consultar(admin)).body.data.groups).toEqual([]);

    await ordenDetenida({ dias: 4 });
    expect(grupo(await consultar(admin)).total).toBe(1);
  });

  it('test_aplica_a_los_cuatro_estados_abiertos', async () => {
    for (const status of ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION']) {
      await ordenDetenida({ status, dias: 6 });
    }

    const res = await consultar(admin);

    expect(grupo(res).total).toBe(4);
  });

  it('test_una_orden_terminada_o_entregada_nunca_es_detenida', async () => {
    await ordenDetenida({ status: 'TERMINADO', dias: 30 });
    await ordenDetenida({ status: 'ENTREGADO', dias: 30 });

    const res = await consultar(admin);

    expect(res.body.data.groups).toEqual([]);
  });

  it('test_la_fecha_del_ultimo_cambio_es_la_mas_reciente_del_historial', async () => {
    const orden = await ordenDetenida({ dias: 10 });
    await query(
      "INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at) VALUES (?, 'RECIBIDO', 'ESPERANDO_REFACCION', ?, ?)",
      [orden.id, recepcion.id, haceDias(1)],
    );

    const res = await consultar(admin);

    expect(res.body.data.groups).toEqual([]);
  });

  it('test_sin_historial_se_usa_la_fecha_de_creacion_de_la_orden', async () => {
    const orden = await ordenDetenida({ dias: 1 });
    await query('DELETE FROM order_status_history WHERE order_id = ?', [orden.id]);
    await query('UPDATE service_orders SET created_at = ? WHERE id = ?', [haceDias(8), orden.id]);

    const res = await consultar(admin);

    const aviso = grupo(res).items[0];
    expect(aviso.key).toBe(`STALLED:${orden.id}:0`);
    expect(aviso.daysStalled).toBe(8);
  });

  it('test_un_cambio_de_estado_quita_el_aviso_y_reinicia_el_conteo', async () => {
    const orden = await ordenDetenida({ dias: 6 });
    expect(grupo(await consultar(admin)).total).toBe(1);

    await query("UPDATE service_orders SET status = 'EN_REPARACION' WHERE id = ?", [orden.id]);
    await query(
      "INSERT INTO order_status_history (order_id, from_status, to_status, changed_by) VALUES (?, 'ESPERANDO_REFACCION', 'EN_REPARACION', ?)",
      [orden.id, recepcion.id],
    );
    const res = await consultar(admin);

    expect(res.body.data.groups).toEqual([]);
  });

  it('test_si_la_orden_vuelve_a_detenerse_el_aviso_reaparece_sin_leer_con_otra_clave', async () => {
    const orden = await ordenDetenida({ dias: 6 });
    const primera = (await consultar(admin)).body.data.groups[0].items[0];
    await marcar(admin, [primera.key]);
    expect((await consultar(admin)).body.data.unread).toBe(0);

    // La orden cambia de estado y, días después, vuelve a quedar detenida.
    await query("UPDATE service_orders SET status = 'EN_REPARACION' WHERE id = ?", [orden.id]);
    await query(
      "INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at) VALUES (?, 'ESPERANDO_REFACCION', 'EN_REPARACION', ?, ?)",
      [orden.id, recepcion.id, haceDias(5)],
    );
    const res = await consultar(admin);

    const nueva = grupo(res).items[0];
    expect(nueva.key).not.toBe(primera.key);
    expect(nueva.key.startsWith(`STALLED:${orden.id}:`)).toBe(true);
    expect(nueva.read).toBe(false);
    expect(res.body.data.unread).toBe(1);
  });

  it('test_el_administrador_y_la_recepcion_reciben_el_aviso_y_ordenan_primero_la_mas_detenida', async () => {
    const poco = await ordenDetenida({ dias: 5 });
    const mucho = await ordenDetenida({ dias: 12 });

    for (const usuario of [admin, recepcion]) {
      const res = await consultar(usuario);
      expect(grupo(res).items.map((i) => i.target.id)).toEqual([mucho.id, poco.id]);
    }
  });

  it('test_una_orden_sin_mecanico_asignado_tambien_se_avisa_a_administracion_y_recepcion', async () => {
    await ordenDetenida({ dias: 5, mechanicId: null });

    expect(grupo(await consultar(admin)).total).toBe(1);
    expect(grupo(await consultar(recepcion)).total).toBe(1);
  });

  it('test_el_mecanico_solo_recibe_las_ordenes_detenidas_que_tiene_asignadas', async () => {
    const otro = await createUserWithToken('MECHANIC');
    const mia = await ordenDetenida({ dias: 5 });
    await ordenDetenida({ dias: 5, mechanicId: otro.id });
    await ordenDetenida({ dias: 5, mechanicId: null });

    const res = await consultar(mecanico);

    expect(grupo(res).total).toBe(1);
    expect(grupo(res).items[0].target.id).toBe(mia.id);
    expect(grupo(res).items[0].detail).not.toContain('Ana Torres');
  });
});
