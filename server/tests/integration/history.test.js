import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let otroMecanico;
let vehiculo;

const historial = (user, id = vehiculo.id, q = '') => request(app).get(`/api/vehicles/${id}/history${q}`).set(auth(user.token));

/** Registra la fecha en que la orden pasó a Terminado (para controlar el orden cronológico). */
async function terminadaEl(orden, fecha) {
  await query('INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at) VALUES (?, ?, ?, ?, ?)', [
    orden.id,
    'EN_REPARACION',
    'TERMINADO',
    mecanico.id,
    fecha,
  ]);
}

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'HIS-100-A', currentMileage: 80000 }));
});

describe('historial del vehículo (US1, CA-1)', () => {
  it('test_muestra_las_ordenes_terminadas_en_orden_cronologico_la_mas_reciente_primero', async () => {
    const vieja = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', reportedProblem: 'Vieja' });
    const nueva = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'TERMINADO', reportedProblem: 'Nueva' });
    const media = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', reportedProblem: 'Media' });
    await terminadaEl(vieja, '2026-01-10 10:00:00');
    await terminadaEl(media, '2026-05-10 10:00:00');
    await terminadaEl(nueva, '2026-09-10 10:00:00');

    const res = await historial(mecanico);

    expect(res.status).toBe(200);
    expect(res.body.data.entries.map((e) => e.reportedProblem)).toEqual(['Nueva', 'Media', 'Vieja']);
    expect(res.body.meta.total).toBe(3);
  });

  it('test_no_muestra_como_servicio_realizado_una_orden_abierta', async () => {
    await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', reportedProblem: 'Entregada' });
    await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION', reportedProblem: 'Abierta' });

    const res = await historial(recepcion);

    expect(res.body.data.entries.map((e) => e.reportedProblem)).toEqual(['Entregada']);
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])(
    'test_una_orden_en_estado_%s_no_aparece',
    async (estado) => {
      await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: estado });

      const res = await historial(recepcion);

      expect(res.body.data.entries).toEqual([]);
    },
  );

  it('test_un_vehiculo_sin_servicios_terminados_devuelve_el_historial_vacio', async () => {
    const res = await historial(mecanico);

    expect(res.status).toBe(200);
    expect(res.body.data.entries).toEqual([]);
    expect(res.body.data.pendingMaintenance).toBeNull();
    expect(res.body.meta.total).toBe(0);
  });

  it('test_una_orden_que_pasa_a_terminado_aparece_de_inmediato', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
    expect((await historial(mecanico)).body.data.entries).toHaveLength(0);

    const cambio = await request(app).post(`/api/orders/${orden.id}/status`).set(auth(mecanico.token)).send({ status: 'TERMINADO' });
    expect(cambio.status).toBe(200);

    const res = await historial(mecanico);
    expect(res.body.data.entries).toHaveLength(1);
    expect(res.body.data.entries[0]).toMatchObject({ orderId: orden.id, status: 'TERMINADO' });
  });

  it('test_el_kilometraje_usa_el_del_servicio_y_cae_al_de_entrada_si_no_existe', async () => {
    const conServicio = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 70000 });
    await query('UPDATE service_orders SET service_mileage = 70120 WHERE id = ?', [conServicio.id]);
    await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 75000 });

    const res = await historial(mecanico);
    const kilometrajes = Object.fromEntries(res.body.data.entries.map((e) => [e.orderId, e.mileage]));

    expect(kilometrajes[conServicio.id]).toBe(70120);
    expect(Object.values(kilometrajes).sort()).toEqual([70120, 75000]);
  });

  it('test_un_mecanico_ve_el_historial_de_un_vehiculo_que_no_atendio', async () => {
    await createFinishedOrder(vehiculo.id, recepcion.id, otroMecanico.id, { status: 'ENTREGADO' });

    const res = await historial(mecanico);

    expect(res.status).toBe(200);
    expect(res.body.data.entries).toHaveLength(1);
    expect(res.body.data.entries[0].mechanic.id).toBe(otroMecanico.id);
  });

  it('test_pagina_el_historial', async () => {
    for (let i = 0; i < 3; i += 1) {
      const orden = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', reportedProblem: `Servicio ${i}` });
      await terminadaEl(orden, `2026-0${i + 1}-10 10:00:00`);
    }

    const primera = await historial(mecanico, vehiculo.id, '?page=1&pageSize=2');
    const segunda = await historial(mecanico, vehiculo.id, '?page=2&pageSize=2');

    expect(primera.body.data.entries.map((e) => e.reportedProblem)).toEqual(['Servicio 2', 'Servicio 1']);
    expect(segunda.body.data.entries.map((e) => e.reportedProblem)).toEqual(['Servicio 0']);
    expect(primera.body.meta).toEqual({ page: 1, pageSize: 2, total: 3 });
  });

  it('test_no_mezcla_las_ordenes_de_otro_vehiculo', async () => {
    const { vehicle: otro } = await createClientWithVehicle({ licensePlate: 'HIS-200-B' });
    await createFinishedOrder(otro.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', reportedProblem: 'Ajena' });

    const res = await historial(mecanico);

    expect(res.body.data.entries).toEqual([]);
  });
});
