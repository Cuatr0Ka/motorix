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
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let cliente;
let vehiculo;

const crear = (body, user = recepcion) => request(app).post('/api/orders').set(auth(user.token)).send(body);
const directa = (extra = {}) => ({ vehicleId: vehiculo.id, entryMileage: 51000, reportedProblem: 'Ruido al frenar', ...extra });
const kilometrajeDelVehiculo = async (id = vehiculo.id) =>
  (await query('SELECT current_mileage FROM vehicles WHERE id = ?', [id]))[0].current_mileage;

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle(
    { licensePlate: 'ORD-100-A', currentMileage: 50000 },
    { name: 'Ana Morales' },
  ));
});

describe('crear una orden asociada a cliente y vehículo (US2, RN-2, CA-2)', () => {
  it('test_la_orden_nace_recibida_con_el_cliente_derivado_del_propietario', async () => {
    const res = await crear(directa());

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('RECIBIDO');
    expect(res.body.data.client).toEqual({ id: cliente.id, name: 'Ana Morales' });
    expect(res.body.data.vehicle.id).toBe(vehiculo.id);
    const [fila] = await query('SELECT client_id, created_by FROM service_orders WHERE id = ?', [res.body.data.id]);
    expect(fila).toEqual({ client_id: cliente.id, created_by: recepcion.id });
  });

  it('test_el_folio_es_unico_y_se_deriva_del_identificador', async () => {
    const primera = await crear(directa());
    await query("UPDATE service_orders SET status = 'ENTREGADO'");
    const segunda = await crear(directa({ entryMileage: 52000 }));

    expect(primera.body.data.folio).toBe(`OS-${String(primera.body.data.id).padStart(6, '0')}`);
    expect(segunda.body.data.folio).not.toBe(primera.body.data.folio);
  });

  it('test_el_administrador_tambien_puede_crear_ordenes', async () => {
    expect((await crear(directa(), admin)).status).toBe(201);
  });

  it('test_rechaza_un_vehiculo_inexistente_y_no_guarda_nada', async () => {
    const res = await crear(directa({ vehicleId: 999999 }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VEHICLE_NOT_FOUND');
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM service_orders');
    expect(Number(total)).toBe(0);
  });

  it('test_exige_el_vehiculo_o_la_cita_pero_no_ambos', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const ninguno = await crear({ entryMileage: 51000, reportedProblem: 'x' });
    const ambos = await crear({ vehicleId: vehiculo.id, appointmentId: cita.id, entryMileage: 51000, reportedProblem: 'x' });

    expect(ninguno.status).toBe(400);
    expect(ambos.status).toBe(400);
    expect(ambos.body.error.details.map((d) => d.field)).toContain('appointmentId');
  });

  it('test_el_problema_reportado_es_obligatorio_en_una_orden_directa', async () => {
    const res = await crear({ vehicleId: vehiculo.id, entryMileage: 51000, reportedProblem: '   ' });

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('reportedProblem');
  });

  it('test_asigna_un_mecanico_activo_al_crear_y_rechaza_uno_invalido', async () => {
    const mecanico = await createUserWithToken('MECHANIC');
    const inactivo = await createUserWithToken('MECHANIC', { active: 0 });

    const bien = await crear(directa({ mechanicId: mecanico.id }));
    expect(bien.body.data.mechanic).toEqual({ id: mecanico.id, name: expect.any(String) });
    await query("UPDATE service_orders SET status = 'ENTREGADO'");

    for (const mechanicId of [inactivo.id, recepcion.id, 999999]) {
      const res = await crear(directa({ mechanicId }));
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('MECHANIC_INVALID');
    }
  });
});

describe('kilometraje de entrada (RN-3, RN-4, CA-6)', () => {
  it('test_el_kilometraje_de_entrada_es_obligatorio', async () => {
    const res = await crear({ vehicleId: vehiculo.id, reportedProblem: 'x' });

    expect(res.status).toBe(400);
    expect(await kilometrajeDelVehiculo()).toBe(50000);
  });

  it('test_rechaza_un_kilometraje_menor_al_actual_sin_correccion_y_no_cambia_nada', async () => {
    const res = await crear(directa({ entryMileage: 49000 }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MILEAGE_DECREASE');
    expect(await kilometrajeDelVehiculo()).toBe(50000);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM service_orders');
    expect(Number(total)).toBe(0);
  });

  it('test_acepta_el_kilometraje_menor_con_correccion_explicita_y_la_registra', async () => {
    const res = await crear(
      directa({ entryMileage: 45000, mileageCorrection: true, mileageCorrectionReason: 'Tablero reemplazado' }),
    );

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ mileageCorrection: true, mileageCorrectionReason: 'Tablero reemplazado', entryMileage: 45000 });
    expect(await kilometrajeDelVehiculo()).toBe(45000);
  });

  it('test_la_correccion_exige_un_motivo', async () => {
    const res = await crear(directa({ entryMileage: 45000, mileageCorrection: true }));

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('mileageCorrectionReason');
  });

  it('test_actualiza_el_kilometraje_actual_del_vehiculo_con_el_de_entrada', async () => {
    await crear(directa({ entryMileage: 50000 }));
    expect(await kilometrajeDelVehiculo()).toBe(50000);

    await query("UPDATE service_orders SET status = 'ENTREGADO'");
    await crear(directa({ entryMileage: 53500 }));
    expect(await kilometrajeDelVehiculo()).toBe(53500);
  });

  it('test_acepta_cualquier_valor_valido_si_el_vehiculo_no_tiene_kilometraje_previo', async () => {
    const sinKm = await createVehicle(cliente.id, { licensePlate: 'ORD-200-B', currentMileage: null });

    const res = await crear({ vehicleId: sinKm.id, entryMileage: 123, reportedProblem: 'Revisión' });

    expect(res.status).toBe(201);
    expect(await kilometrajeDelVehiculo(sinKm.id)).toBe(123);
  });

  it.each([-1, 2000001, 10.5, '5000'])('test_rechaza_el_kilometraje_invalido_%s', async (valor) => {
    const res = await crear(directa({ entryMileage: valor }));

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('entryMileage');
  });
});

describe('una sola orden abierta por vehículo (FR-012)', () => {
  it('test_rechaza_una_segunda_orden_abierta_con_el_detalle_de_la_existente', async () => {
    const primera = await crear(directa());

    const res = await crear(directa({ entryMileage: 52000 }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('OPEN_ORDER_EXISTS');
    expect(res.body.error.details).toEqual({ orderId: primera.body.data.id, folio: primera.body.data.folio });
  });

  it('test_permite_otra_orden_cuando_la_anterior_ya_fue_entregada', async () => {
    await crear(directa());
    await query("UPDATE service_orders SET status = 'ENTREGADO'");

    expect((await crear(directa({ entryMileage: 52000 }))).status).toBe(201);
  });

  it('test_de_dos_creaciones_simultaneas_solo_una_prospera', async () => {
    const respuestas = await Promise.all([crear(directa()), crear(directa())]);

    expect(respuestas.map((r) => r.status).sort()).toEqual([201, 409]);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM service_orders WHERE vehicle_id = ?', [vehiculo.id]);
    expect(Number(total)).toBe(1);
  });

  it('test_dos_vehiculos_distintos_pueden_tener_cada_uno_su_orden_abierta', async () => {
    const otro = await createVehicle(cliente.id, { licensePlate: 'ORD-300-C', currentMileage: 100 });

    expect((await crear(directa())).status).toBe(201);
    expect((await crear({ vehicleId: otro.id, entryMileage: 200, reportedProblem: 'Revisión' })).status).toBe(201);
  });
});

describe('crear desde una cita (US2)', () => {
  it('test_hereda_vehiculo_y_motivo_y_pasa_la_cita_a_en_proceso', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { reason: 'Afinación mayor', status: 'CONFIRMADA' });

    const res = await crear({ appointmentId: cita.id, entryMileage: 51000 });

    expect(res.status).toBe(201);
    expect(res.body.data.reportedProblem).toBe('Afinación mayor');
    expect(res.body.data.vehicle.id).toBe(vehiculo.id);
    const [fila] = await query('SELECT status FROM appointments WHERE id = ?', [cita.id]);
    expect(fila.status).toBe('EN_PROCESO');
  });

  it('test_el_problema_reportado_capturado_prevalece_sobre_el_motivo_de_la_cita', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { reason: 'Afinación mayor' });

    const res = await crear({ appointmentId: cita.id, entryMileage: 51000, reportedProblem: 'Falla el motor en frío' });

    expect(res.body.data.reportedProblem).toBe('Falla el motor en frío');
  });

  it.each(['CANCELADA', 'COMPLETADA', 'EN_PROCESO'])('test_rechaza_crear_una_orden_desde_una_cita_%s', async (estado) => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { status: estado });

    const res = await crear({ appointmentId: cita.id, entryMileage: 51000 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('APPOINTMENT_NOT_AVAILABLE');
  });

  it('test_rechaza_una_cita_inexistente', async () => {
    const res = await crear({ appointmentId: 999999, entryMileage: 51000 });

    expect(res.status).toBe(404);
  });

  it('test_una_cita_no_puede_originar_dos_ordenes', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);
    expect((await crear({ appointmentId: cita.id, entryMileage: 51000 })).status).toBe(201);
    await query("UPDATE service_orders SET status = 'ENTREGADO'");

    const otra = await crear({ appointmentId: cita.id, entryMileage: 52000 });

    expect(otra.status).toBe(409);
    expect(otra.body.error.code).toBe('APPOINTMENT_NOT_AVAILABLE');
  });

  it('test_si_falla_la_validacion_la_cita_y_el_kilometraje_quedan_intactos', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await crear({ appointmentId: cita.id, entryMileage: 10 });

    expect(res.status).toBe(422);
    const [fila] = await query('SELECT status FROM appointments WHERE id = ?', [cita.id]);
    expect(fila.status).toBe('PENDIENTE');
    expect(await kilometrajeDelVehiculo()).toBe(50000);
  });
});

describe('historial y conservación (RN-9)', () => {
  it('test_la_creacion_deja_la_entrada_inicial_del_historial', async () => {
    const res = await crear(directa());

    const filas = await query('SELECT from_status, to_status, changed_by FROM order_status_history WHERE order_id = ?', [res.body.data.id]);
    expect(filas).toEqual([{ from_status: null, to_status: 'RECIBIDO', changed_by: recepcion.id }]);
  });

  it('test_no_existe_la_operacion_de_borrar_ordenes', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await request(app).delete(`/api/orders/${orden.id}`).set(auth(admin.token));

    expect(res.status).toBe(404);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM service_orders');
    expect(Number(total)).toBe(1);
  });

  it('test_no_se_puede_borrar_un_cliente_o_vehiculo_con_ordenes', async () => {
    const otro = await createClient({ name: 'Otro' });
    expect(otro.id).toBeDefined();
    await createOrder(vehiculo.id, recepcion.id);

    await expect(query('DELETE FROM vehicles WHERE id = ?', [vehiculo.id])).rejects.toMatchObject({ code: 'ER_ROW_IS_REFERENCED_2' });
  });
});
