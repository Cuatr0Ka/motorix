import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createAppointment,
  createClient,
  createClientWithVehicle,
  createOrder,
  createUserWithToken,
  createVehicle,
  hoursFromNow,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let cliente;
let vehiculo;

const crear = (body, user = recepcion) => request(app).post('/api/appointments').set(auth(user.token)).send(body);
const base = (extra = {}) => ({
  clientId: cliente.id,
  vehicleId: vehiculo.id,
  scheduledAt: hoursFromNow(72).toISOString(),
  reason: 'Cambio de aceite',
  ...extra,
});
const accion = (id, nombre, body, user = recepcion) =>
  request(app).post(`/api/appointments/${id}/${nombre}`).set(auth(user.token)).send(body ?? {});

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'FLU-001-A' }, { name: 'Ana Morales' }));
});

describe('registrar y consultar citas (US1)', () => {
  it('test_la_cita_nueva_queda_pendiente_y_aparece_en_el_listado', async () => {
    const res = await crear(base({ notes: 'Llega por la mañana' }));

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('PENDIENTE');
    const lista = await request(app).get('/api/appointments').set(auth(recepcion.token));
    expect(lista.body.data.map((c) => c.id)).toEqual([res.body.data.id]);
    const [fila] = await query('SELECT created_by FROM appointments WHERE id = ?', [res.body.data.id]);
    expect(fila.created_by).toBe(recepcion.id);
  });

  it('test_el_administrador_tambien_puede_registrar_citas', async () => {
    expect((await crear(base(), admin)).status).toBe(201);
  });

  it('test_rechaza_una_fecha_pasada', async () => {
    const res = await crear(base({ scheduledAt: hoursFromNow(-5).toISOString() }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('APPOINTMENT_IN_PAST');
  });

  it('test_rechaza_un_vehiculo_que_no_pertenece_al_cliente', async () => {
    const otro = await createClient({ name: 'Otro Cliente' });

    const res = await crear(base({ clientId: otro.id }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VEHICLE_CLIENT_MISMATCH');
  });

  it('test_rechaza_cliente_o_vehiculo_inexistente', async () => {
    const sinVehiculo = await crear(base({ vehicleId: 999999 }));
    const sinCliente = await crear(base({ clientId: 999999 }));

    expect(sinVehiculo.status).toBe(422);
    expect(sinVehiculo.body.error.code).toBe('VEHICLE_NOT_FOUND');
    expect(sinCliente.status).toBe(422);
    expect(sinCliente.body.error.code).toBe('VEHICLE_NOT_FOUND');
  });

  it('test_rechaza_otra_cita_activa_del_mismo_vehiculo_en_el_mismo_horario', async () => {
    const horario = hoursFromNow(96).toISOString();
    expect((await crear(base({ scheduledAt: horario }))).status).toBe(201);

    const res = await crear(base({ scheduledAt: horario }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('APPOINTMENT_SLOT_TAKEN');
  });

  it('test_de_dos_solicitudes_simultaneas_al_mismo_horario_solo_una_prospera', async () => {
    const horario = hoursFromNow(100).toISOString();

    const respuestas = await Promise.all([crear(base({ scheduledAt: horario })), crear(base({ scheduledAt: horario }))]);

    expect(respuestas.map((r) => r.status).sort()).toEqual([201, 409]);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM appointments');
    expect(Number(total)).toBe(1);
  });

  it('test_un_horario_liberado_por_una_cancelacion_puede_reutilizarse', async () => {
    const horario = hoursFromNow(120).toISOString();
    const primera = await crear(base({ scheduledAt: horario }));
    await accion(primera.body.data.id, 'cancel');

    const segunda = await crear(base({ scheduledAt: horario }));

    expect(segunda.status).toBe(201);
  });

  it('test_dos_vehiculos_distintos_pueden_tener_cita_en_el_mismo_horario', async () => {
    const otroVehiculo = await createVehicle(cliente.id, { licensePlate: 'FLU-002-B' });
    const horario = hoursFromNow(80).toISOString();

    expect((await crear(base({ scheduledAt: horario }))).status).toBe(201);
    expect((await crear(base({ scheduledAt: horario, vehicleId: otroVehiculo.id }))).status).toBe(201);
  });
});

describe('modificar, confirmar y cancelar (US1)', () => {
  it('test_confirma_modifica_y_cancela_una_cita', async () => {
    const cita = (await crear(base())).body.data;

    const confirmada = await accion(cita.id, 'confirm');
    expect(confirmada.body.data.status).toBe('CONFIRMADA');

    const nuevaHora = hoursFromNow(200).toISOString();
    const modificada = await request(app)
      .patch(`/api/appointments/${cita.id}`)
      .set(auth(recepcion.token))
      .send({ scheduledAt: nuevaHora, reason: 'Afinación', notes: 'Con prisa' });
    expect(modificada.status).toBe(200);
    expect(modificada.body.data).toMatchObject({ reason: 'Afinación', notes: 'Con prisa', status: 'CONFIRMADA' });
    expect(new Date(modificada.body.data.scheduledAt).getTime()).toBe(Math.floor(Date.parse(nuevaHora) / 1000) * 1000);

    const cancelada = await accion(cita.id, 'cancel', { reason: 'No podrá asistir' });
    expect(cancelada.body.data).toMatchObject({ status: 'CANCELADA', cancelReason: 'No podrá asistir' });
  });

  it('test_cancela_sin_motivo_y_la_cita_se_conserva', async () => {
    const cita = (await crear(base())).body.data;

    const res = await accion(cita.id, 'cancel');

    expect(res.status).toBe(200);
    expect(res.body.data.cancelReason).toBeNull();
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM appointments WHERE id = ?', [cita.id]);
    expect(Number(total)).toBe(1);
  });

  it('test_no_se_modifica_ni_cancela_ni_confirma_una_cita_cancelada', async () => {
    const cita = (await crear(base())).body.data;
    await accion(cita.id, 'cancel');

    const modificar = await request(app).patch(`/api/appointments/${cita.id}`).set(auth(recepcion.token)).send({ reason: 'x' });
    const cancelar = await accion(cita.id, 'cancel');
    const confirmar = await accion(cita.id, 'confirm');

    for (const res of [modificar, cancelar, confirmar]) {
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('APPOINTMENT_NOT_EDITABLE');
    }
  });

  it.each(['EN_PROCESO', 'COMPLETADA'])('test_no_se_modifica_ni_cancela_una_cita_%s', async (estado) => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { status: estado });

    const modificar = await request(app).patch(`/api/appointments/${cita.id}`).set(auth(recepcion.token)).send({ reason: 'x' });
    const cancelar = await accion(cita.id, 'cancel');

    expect(modificar.status).toBe(409);
    expect(cancelar.status).toBe(409);
    expect(cancelar.body.error.code).toBe('APPOINTMENT_NOT_EDITABLE');
  });

  it('test_solo_se_confirma_una_cita_pendiente', async () => {
    const cita = (await crear(base())).body.data;
    await accion(cita.id, 'confirm');

    const otra = await accion(cita.id, 'confirm');

    expect(otra.status).toBe(409);
  });

  it('test_modificar_a_una_fecha_pasada_o_a_un_horario_ocupado_se_rechaza', async () => {
    const horario = hoursFromNow(150).toISOString();
    await crear(base({ scheduledAt: horario }));
    const cita = (await crear(base())).body.data;

    const pasada = await request(app)
      .patch(`/api/appointments/${cita.id}`)
      .set(auth(recepcion.token))
      .send({ scheduledAt: hoursFromNow(-3).toISOString() });
    const ocupado = await request(app)
      .patch(`/api/appointments/${cita.id}`)
      .set(auth(recepcion.token))
      .send({ scheduledAt: horario });

    expect(pasada.body.error.code).toBe('APPOINTMENT_IN_PAST');
    expect(ocupado.body.error.code).toBe('APPOINTMENT_SLOT_TAKEN');
  });

  it('test_editar_el_motivo_no_exige_fecha_futura_si_la_hora_no_cambia', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { scheduledAt: hoursFromNow(-2) });

    const res = await request(app).patch(`/api/appointments/${cita.id}`).set(auth(recepcion.token)).send({ reason: 'Nuevo motivo' });

    expect(res.status).toBe(200);
  });

  it('test_la_cita_muestra_la_orden_que_origino', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { status: 'EN_PROCESO' });
    const orden = await createOrder(vehiculo.id, recepcion.id, { appointmentId: cita.id });

    const res = await request(app).get(`/api/appointments/${cita.id}`).set(auth(recepcion.token));

    expect(res.body.data.order).toEqual({ id: orden.id, folio: `OS-${String(orden.id).padStart(6, '0')}`, status: 'RECIBIDO' });
  });
});

describe('listado, filtros y búsqueda (US1)', () => {
  it('test_filtra_por_estado_fechas_y_busca_por_cliente_o_placa', async () => {
    const otro = await createClientWithVehicle({ licensePlate: 'ZZZ-999-Z' }, { name: 'Roberto Sánchez' });
    const c1 = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { scheduledAt: hoursFromNow(24) });
    const c2 = await createAppointment(otro.client.id, otro.vehicle.id, recepcion.id, {
      scheduledAt: hoursFromNow(200),
      status: 'CONFIRMADA',
    });

    const lista = (q) => request(app).get(`/api/appointments${q}`).set(auth(recepcion.token));
    const ids = (res) => res.body.data.map((c) => c.id);

    expect(ids(await lista(''))).toEqual([c1.id, c2.id]); // orden por fecha ascendente
    expect(ids(await lista('?status=CONFIRMADA'))).toEqual([c2.id]);
    expect(ids(await lista('?search=Roberto'))).toEqual([c2.id]);
    expect(ids(await lista('?search=ZZZ-999'))).toEqual([c2.id]);
    expect(ids(await lista(`?from=${encodeURIComponent(hoursFromNow(100).toISOString())}`))).toEqual([c2.id]);
    expect(ids(await lista(`?to=${encodeURIComponent(hoursFromNow(100).toISOString())}`))).toEqual([c1.id]);
  });

  it('test_pagina_los_resultados', async () => {
    for (let i = 1; i <= 3; i += 1) {
      await createAppointment(cliente.id, vehiculo.id, recepcion.id, { scheduledAt: hoursFromNow(i * 10) });
    }

    const res = await request(app).get('/api/appointments?page=2&pageSize=2').set(auth(recepcion.token));

    expect(res.body.data).toHaveLength(1);
    expect(res.body.meta).toEqual({ page: 2, pageSize: 2, total: 3 });
  });

  it('test_no_existe_la_operacion_de_borrar_citas', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await request(app).delete(`/api/appointments/${cita.id}`).set(auth(admin.token));

    expect(res.status).toBe(404);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM appointments');
    expect(Number(total)).toBe(1);
  });
});
