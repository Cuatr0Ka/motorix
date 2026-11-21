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
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let seq = 0;

const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

/** Fecha a una hora fija (para no depender de la hora a la que corre la prueba). */
const diaALas = (diasDesdeHoy, hora = 10) => {
  const ahora = new Date();
  return new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + diasDesdeHoy, hora, 0, 0);
};

async function nuevoVehiculo(cliente = 'Ana Torres', telefono = '7761234567') {
  seq += 1;
  return createClientWithVehicle(
    { licensePlate: `AVI-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 },
    { name: cliente, phone: telefono },
  );
}

/** Orden Terminada sin entregar de un cliente nuevo. */
async function ordenTerminada(cliente, telefono) {
  const { client, vehicle } = await nuevoVehiculo(cliente, telefono);
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 });
  return { client, vehicle, orden };
}

async function citaDeManana({ status = 'PENDIENTE', cliente = 'Luis Gómez' } = {}) {
  const { client, vehicle } = await nuevoVehiculo(cliente);
  const cita = await createAppointment(client.id, vehicle.id, recepcion.id, { scheduledAt: diaALas(1, 11), status });
  return { client, vehicle, cita };
}

async function mantenimiento({ dias, cliente = 'Juan Pérez', descripcion = 'Cambio de aceite' }) {
  const { client, vehicle } = await nuevoVehiculo(cliente);
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  const m = await createMaintenance(vehicle.id, orden.id, mecanico.id, { description: descripcion, dueDate: hoyMas(dias) });
  return { client, vehicle, mantenimiento: m };
}

const listar = (user) => request(app).get('/api/client-notices').set(auth(user.token));
const avisar = (user, reason, factId) =>
  request(app).post('/api/client-notices').set(auth(user.token)).send({ reason, factId });
const motivos = (res) => res.body.data.map((fila) => `${fila.reason}:${fila.factId}`);

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('lista de clientes por avisar (US7, FR-014)', () => {
  it('test_incluye_los_cuatro_motivos_con_cliente_telefono_y_vehiculo', async () => {
    const terminada = await ordenTerminada('Ana Torres', '7761234567');
    const cita = await citaDeManana({ cliente: 'Luis Gómez' });
    const proximo = await mantenimiento({ dias: 10, descripcion: 'Próximo por fecha' });
    const vencido = await mantenimiento({ dias: -4, descripcion: 'Vencido por fecha' });

    const res = await listar(recepcion);

    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(4);
    expect(motivos(res)).toEqual([
      `ORDER_READY:${terminada.orden.id}`,
      `APPT_TOMORROW:${cita.cita.id}`,
      `MAINT_OVERDUE:${vencido.mantenimiento.id}`,
      `MAINT_UPCOMING:${proximo.mantenimiento.id}`,
    ]);

    const [listo, mañana, venc, prox] = res.body.data;
    expect(listo.client).toEqual({ id: terminada.client.id, name: 'Ana Torres', phone: '7761234567' });
    expect(listo.vehicle).toMatchObject({ id: terminada.vehicle.id, licensePlate: 'AVI-001-Z' });
    expect(listo.folio).toMatch(/^OS-\d{6}$/);
    expect(listo.description).toBe('Orden terminada, lista para entregar');
    expect(listo.factDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(mañana.client.name).toBe('Luis Gómez');
    expect(mañana.folio).toBeUndefined();
    expect(mañana.description).toContain('11:00');
    expect(venc.description).toBe('Vencido por fecha');
    expect(prox.description).toBe('Próximo por fecha');
  });

  it('test_el_administrador_tambien_ve_la_lista', async () => {
    await ordenTerminada();

    const res = await listar(admin);

    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(1);
  });

  it('test_no_aparecen_ordenes_entregadas_citas_canceladas_ni_mantenimientos_atendidos', async () => {
    const { vehicle } = await nuevoVehiculo();
    await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
    await citaDeManana({ status: 'CANCELADA' });
    const atendido = await mantenimiento({ dias: -4 });
    await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [atendido.mantenimiento.id]);
    const normal = await mantenimiento({ dias: 120 });
    expect(normal.mantenimiento.id).toBeGreaterThan(0);

    const res = await listar(recepcion);

    expect(res.body.data).toEqual([]);
    expect(res.body.meta.total).toBe(0);
  });

  it('test_una_cita_de_hoy_o_de_pasado_manana_no_es_cita_de_manana', async () => {
    for (const dia of [0, 2]) {
      const { client, vehicle } = await nuevoVehiculo();
      await createAppointment(client.id, vehicle.id, recepcion.id, { scheduledAt: diaALas(dia, 11) });
    }

    const res = await listar(recepcion);

    expect(res.body.data).toEqual([]);
  });

  it('test_un_cliente_con_dos_motivos_aparece_una_vez_por_motivo', async () => {
    const { client, vehicle } = await nuevoVehiculo('Rosa Díaz');
    const vieja = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
    await createMaintenance(vehicle.id, vieja.id, mecanico.id, { description: 'Afinación', dueDate: hoyMas(-3) });
    const nueva = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 });

    const res = await listar(recepcion);

    expect(res.body.data).toHaveLength(2);
    expect(res.body.data.map((f) => f.client.id)).toEqual([client.id, client.id]);
    expect(motivos(res)).toContain(`ORDER_READY:${nueva.id}`);
  });

  it('test_un_cliente_sin_telefono_llega_con_telefono_vacio', async () => {
    await ordenTerminada('Sin Teléfono', '');

    const res = await listar(recepcion);

    expect(res.body.data[0].client.phone).toBe('');
  });

  it('test_limita_a_doscientas_filas_pero_informa_el_total_real', async () => {
    for (let i = 0; i < 205; i += 1) {
      const { vehicle } = await nuevoVehiculo(`Cliente ${i}`);
      await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO', entryMileage: 0 });
    }

    const res = await listar(recepcion);

    expect(res.body.data).toHaveLength(200);
    expect(res.body.meta.total).toBe(205);
  });
});

describe('marcar como avisado (US7, FR-016, FR-017, FR-018)', () => {
  it('test_marcar_registra_quien_y_cuando_saca_la_fila_y_no_reaparece', async () => {
    const { client, orden } = await ordenTerminada('Ana Torres');

    const res = await avisar(recepcion, 'ORDER_READY', orden.id);

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ reason: 'ORDER_READY', factId: orden.id, clientId: client.id, notifiedBy: recepcion.id });
    expect(Number.isNaN(Date.parse(res.body.data.notifiedAt))).toBe(false);
    const filas = await query('SELECT client_id, reason, fact_id, notified_by FROM client_notices');
    expect(filas).toEqual([{ client_id: client.id, reason: 'ORDER_READY', fact_id: orden.id, notified_by: recepcion.id }]);

    const despues = await listar(recepcion);
    expect(despues.body.data).toEqual([]);
    const otraVez = await listar(admin);
    expect(otraVez.body.data).toEqual([]);
  });

  it('test_un_hecho_nuevo_del_mismo_cliente_vuelve_a_aparecer', async () => {
    const { vehicle, orden } = await ordenTerminada('Ana Torres');
    await avisar(recepcion, 'ORDER_READY', orden.id);
    await query("UPDATE service_orders SET status = 'ENTREGADO', delivered_at = NOW() WHERE id = ?", [orden.id]);

    const nueva = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 });
    const res = await listar(recepcion);

    expect(motivos(res)).toEqual([`ORDER_READY:${nueva.id}`]);
  });

  it('test_se_pueden_avisar_citas_y_mantenimientos', async () => {
    const cita = await citaDeManana();
    const vencido = await mantenimiento({ dias: -4 });
    const proximo = await mantenimiento({ dias: 10 });

    expect((await avisar(recepcion, 'APPT_TOMORROW', cita.cita.id)).status).toBe(201);
    expect((await avisar(recepcion, 'MAINT_OVERDUE', vencido.mantenimiento.id)).status).toBe(201);
    expect((await avisar(recepcion, 'MAINT_UPCOMING', proximo.mantenimiento.id)).status).toBe(201);
    expect((await listar(recepcion)).body.data).toEqual([]);
  });

  it('test_un_mantenimiento_avisado_como_proximo_aparece_de_nuevo_al_vencer', async () => {
    const { mantenimiento: m } = await mantenimiento({ dias: 10 });
    await avisar(recepcion, 'MAINT_UPCOMING', m.id);
    await query('UPDATE maintenance SET due_date = ? WHERE id = ?', [hoyMas(-2), m.id]);

    const res = await listar(recepcion);

    expect(motivos(res)).toEqual([`MAINT_OVERDUE:${m.id}`]);
  });

  it('test_repetir_el_aviso_responde_200_con_el_registro_existente', async () => {
    const { orden } = await ordenTerminada();
    const primero = await avisar(recepcion, 'ORDER_READY', orden.id);

    const segundo = await avisar(admin, 'ORDER_READY', orden.id);

    expect(segundo.status).toBe(200);
    expect(segundo.body.data.id).toBe(primero.body.data.id);
    expect(segundo.body.data.notifiedBy).toBe(recepcion.id);
    expect((await query('SELECT id FROM client_notices')).length).toBe(1);
  });

  it('test_un_hecho_ya_avisado_que_dejo_de_aplicar_sigue_respondiendo_200', async () => {
    const { orden } = await ordenTerminada();
    await avisar(recepcion, 'ORDER_READY', orden.id);
    await query("UPDATE service_orders SET status = 'ENTREGADO', delivered_at = NOW() WHERE id = ?", [orden.id]);

    const res = await avisar(recepcion, 'ORDER_READY', orden.id);

    expect(res.status).toBe(200);
  });

  it('test_un_hecho_que_ya_no_cumple_su_motivo_responde_409', async () => {
    const entregada = await ordenTerminada();
    await query("UPDATE service_orders SET status = 'ENTREGADO', delivered_at = NOW() WHERE id = ?", [entregada.orden.id]);
    const cancelada = await citaDeManana({ status: 'CANCELADA' });
    const atendido = await mantenimiento({ dias: -4 });
    await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [atendido.mantenimiento.id]);
    const normal = await mantenimiento({ dias: 120 });

    for (const [reason, factId] of [
      ['ORDER_READY', entregada.orden.id],
      ['APPT_TOMORROW', cancelada.cita.id],
      ['MAINT_OVERDUE', atendido.mantenimiento.id],
      ['MAINT_UPCOMING', normal.mantenimiento.id],
      ['MAINT_OVERDUE', normal.mantenimiento.id],
    ]) {
      const res = await avisar(recepcion, reason, factId);
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('NOTICE_NOT_APPLICABLE');
    }
    expect((await query('SELECT id FROM client_notices')).length).toBe(0);
  });

  it('test_un_hecho_inexistente_responde_404', async () => {
    for (const reason of ['ORDER_READY', 'APPT_TOMORROW', 'MAINT_UPCOMING', 'MAINT_OVERDUE']) {
      const res = await avisar(recepcion, reason, 99999);
      expect(res.status).toBe(404);
    }
  });

  it('test_no_se_envia_ningun_mensaje_solo_se_registra', async () => {
    const { orden } = await ordenTerminada();

    const res = await avisar(recepcion, 'ORDER_READY', orden.id);

    expect(res.status).toBe(201);
    expect(Object.keys(res.body.data).sort()).toEqual(['clientId', 'factId', 'id', 'notifiedAt', 'notifiedBy', 'reason']);
  });
});
