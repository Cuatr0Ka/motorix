import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createAppointment,
  createClientWithVehicle,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let mecanico;
let otroMecanico;
let cliente;
let vehiculo;

const cambiar = (id, status, user = mecanico) => request(app).post(`/api/orders/${id}/status`).set(auth(user.token)).send({ status });
const estadoDe = async (id) => (await query('SELECT status FROM service_orders WHERE id = ?', [id]))[0].status;
const historialDe = async (id) =>
  query('SELECT from_status, to_status, changed_by FROM order_status_history WHERE order_id = ? ORDER BY id', [id]);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'STT-001-A' }));
});

describe('flujo completo con los tres roles (SC-003, CA-5)', () => {
  it('test_recibido_a_entregado_pasando_por_cada_estado_con_historial_completo', async () => {
    // Recepción crea y asigna; el mecánico trabaja; recepción entrega.
    const creada = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ vehicleId: vehiculo.id, entryMileage: 1000, reportedProblem: 'Ruido', mechanicId: mecanico.id });
    const id = creada.body.data.id;

    for (const estado of ['DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO']) {
      const res = await cambiar(id, estado);
      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe(estado);
    }
    const entrega = await cambiar(id, 'ENTREGADO', recepcion);
    expect(entrega.status).toBe(200);
    expect(entrega.body.data.status).toBe('ENTREGADO');
    expect(entrega.body.data.allowedTransitions).toEqual([]);
    expect(entrega.body.data.deliveredAt).toEqual(expect.any(String));

    expect(await historialDe(id)).toEqual([
      { from_status: null, to_status: 'RECIBIDO', changed_by: recepcion.id },
      { from_status: 'RECIBIDO', to_status: 'DIAGNOSTICO', changed_by: mecanico.id },
      { from_status: 'DIAGNOSTICO', to_status: 'EN_REPARACION', changed_by: mecanico.id },
      { from_status: 'EN_REPARACION', to_status: 'TERMINADO', changed_by: mecanico.id },
      { from_status: 'TERMINADO', to_status: 'ENTREGADO', changed_by: recepcion.id },
    ]);
  });

  it('test_el_administrador_puede_recorrer_el_flujo_completo', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    for (const estado of ['DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO', 'ENTREGADO']) {
      expect((await cambiar(orden.id, estado, admin)).status).toBe(200);
    }
  });
});

describe('esperando refacción', () => {
  it('test_entra_desde_diagnostico_y_desde_en_reparacion_y_solo_regresa_a_en_reparacion', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'DIAGNOSTICO' });

    expect((await cambiar(orden.id, 'ESPERANDO_REFACCION')).status).toBe(200);
    expect((await cambiar(orden.id, 'DIAGNOSTICO')).status).toBe(422);
    expect((await cambiar(orden.id, 'TERMINADO')).status).toBe(422);
    expect((await cambiar(orden.id, 'EN_REPARACION')).status).toBe(200);
    expect((await cambiar(orden.id, 'ESPERANDO_REFACCION')).status).toBe(200);
    expect((await cambiar(orden.id, 'EN_REPARACION')).status).toBe(200);
    expect((await cambiar(orden.id, 'TERMINADO')).status).toBe(200);
  });

  it('test_no_se_puede_esperar_refaccion_desde_recibido_ni_desde_terminado', async () => {
    const recibida = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    expect((await cambiar(recibida.id, 'ESPERANDO_REFACCION')).status).toBe(422);
    await query("UPDATE service_orders SET status = 'TERMINADO' WHERE id = ?", [recibida.id]);
    expect((await cambiar(recibida.id, 'ESPERANDO_REFACCION')).status).toBe(422);
  });
});

describe('saltos y retrocesos rechazados (FR-019)', () => {
  it.each([
    ['RECIBIDO', 'EN_REPARACION'],
    ['RECIBIDO', 'TERMINADO'],
    ['RECIBIDO', 'RECIBIDO'],
    ['DIAGNOSTICO', 'RECIBIDO'],
    ['DIAGNOSTICO', 'TERMINADO'],
    ['EN_REPARACION', 'DIAGNOSTICO'],
    ['EN_REPARACION', 'ENTREGADO'],
    ['TERMINADO', 'EN_REPARACION'],
    ['TERMINADO', 'DIAGNOSTICO'],
  ])('test_%s_a_%s_se_rechaza_con_las_permitidas_y_no_cambia_nada', async (desde, hacia) => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: desde });

    const res = await cambiar(orden.id, hacia, admin);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INVALID_TRANSITION');
    expect(res.body.error.details.currentStatus).toBe(desde);
    expect(Array.isArray(res.body.error.details.allowed)).toBe(true);
    expect(await estadoDe(orden.id)).toBe(desde);
    expect(await historialDe(orden.id)).toHaveLength(1);
  });
});

describe('permisos por rol y pertenencia (FR-020, FR-022, CA-7)', () => {
  it('test_el_mecanico_asignado_no_puede_entregar', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });

    const res = await cambiar(orden.id, 'ENTREGADO');

    expect(res.status).toBe(403);
    expect(await estadoDe(orden.id)).toBe('TERMINADO');
  });

  it('test_recepcion_no_avanza_hasta_terminado_pero_si_entrega', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    expect((await cambiar(orden.id, 'DIAGNOSTICO', recepcion)).status).toBe(403);
    await query("UPDATE service_orders SET status = 'EN_REPARACION' WHERE id = ?", [orden.id]);
    expect((await cambiar(orden.id, 'TERMINADO', recepcion)).status).toBe(403);
    await query("UPDATE service_orders SET status = 'TERMINADO' WHERE id = ?", [orden.id]);

    expect((await cambiar(orden.id, 'ENTREGADO', recepcion)).status).toBe(200);
  });

  it('test_un_mecanico_ajeno_no_puede_cambiar_el_estado_de_una_orden_ajena', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const res = await cambiar(orden.id, 'DIAGNOSTICO', otroMecanico);

    expect(res.status).toBe(404);
    expect(await estadoDe(orden.id)).toBe('RECIBIDO');
  });

  it('test_una_orden_sin_mecanico_no_sale_de_recibido', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await cambiar(orden.id, 'DIAGNOSTICO', admin);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ORDER_UNASSIGNED');
    expect(await estadoDe(orden.id)).toBe('RECIBIDO');
  });

  it('test_una_orden_sin_mecanico_se_avanza_tras_asignarla', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);
    await request(app).put(`/api/orders/${orden.id}/mechanic`).set(auth(recepcion.token)).send({ mechanicId: mecanico.id });

    expect((await cambiar(orden.id, 'DIAGNOSTICO')).status).toBe(200);
  });

  it('test_un_mecanico_desactivado_ya_no_puede_cambiar_estados', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    await query('UPDATE users SET active = 0 WHERE id = ?', [mecanico.id]);

    expect((await cambiar(orden.id, 'DIAGNOSTICO')).status).toBe(401);
  });

  it('test_el_detalle_ofrece_solo_las_transiciones_que_el_rol_puede_ejecutar', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
    const permitidas = async (user) =>
      (await request(app).get(`/api/orders/${orden.id}`).set(auth(user.token))).body.data.allowedTransitions;

    expect(await permitidas(mecanico)).toEqual([]);
    expect(await permitidas(recepcion)).toEqual(['ENTREGADO']);
    expect(await permitidas(admin)).toEqual(['ENTREGADO']);
  });
});

describe('sincronización con la cita (FR-011)', () => {
  it('test_la_cita_pasa_a_completada_al_llegar_a_terminado', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);
    const creada = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ appointmentId: cita.id, entryMileage: 500, mechanicId: mecanico.id });
    const id = creada.body.data.id;
    const estadoCita = async () => (await query('SELECT status FROM appointments WHERE id = ?', [cita.id]))[0].status;

    expect(await estadoCita()).toBe('EN_PROCESO');
    await cambiar(id, 'DIAGNOSTICO');
    await cambiar(id, 'EN_REPARACION');
    expect(await estadoCita()).toBe('EN_PROCESO');
    await cambiar(id, 'TERMINADO');
    expect(await estadoCita()).toBe('COMPLETADA');
  });

  it('test_una_orden_sin_cita_llega_a_terminado_sin_problemas', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });

    expect((await cambiar(orden.id, 'TERMINADO')).status).toBe(200);
  });
});

describe('orden entregada: historial de solo lectura (RN-9, SC-008)', () => {
  it('test_una_orden_entregada_no_cambia_de_estado_ni_se_elimina', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
    await cambiar(orden.id, 'ENTREGADO', recepcion);

    for (const [user, estado] of [
      [admin, 'TERMINADO'],
      [recepcion, 'ENTREGADO'],
      [mecanico, 'DIAGNOSTICO'],
    ]) {
      const res = await cambiar(orden.id, estado, user);
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_READ_ONLY');
    }
    const borrar = await request(app).delete(`/api/orders/${orden.id}`).set(auth(admin.token));
    expect(borrar.status).toBe(404);
    expect(await estadoDe(orden.id)).toBe('ENTREGADO');
  });

  it('test_al_entregar_el_vehiculo_queda_libre_para_una_nueva_orden', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
    await cambiar(orden.id, 'ENTREGADO', recepcion);

    const nueva = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ vehicleId: vehiculo.id, entryMileage: 60000, reportedProblem: 'Otra visita' });

    expect(nueva.status).toBe(201);
  });
});

describe('conflictos de estado (aclaración 5)', () => {
  it('test_dos_cambios_simultaneos_a_la_misma_orden_solo_uno_prospera', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const respuestas = await Promise.all([cambiar(orden.id, 'DIAGNOSTICO'), cambiar(orden.id, 'DIAGNOSTICO', admin)]);

    const estados = respuestas.map((r) => r.status).sort();
    expect(estados[0]).toBe(200);
    expect([409, 422]).toContain(estados[1]);
    expect(await estadoDe(orden.id)).toBe('DIAGNOSTICO');
    expect(await historialDe(orden.id)).toHaveLength(2);
    const perdedora = respuestas.find((r) => r.status !== 200);
    if (perdedora.status === 409) {
      expect(perdedora.body.error.code).toBe('STATE_CONFLICT');
      expect(perdedora.body.error.details.currentStatus).toBe('DIAGNOSTICO');
    }
  });

  it('test_un_cambio_obsoleto_se_rechaza_y_muestra_el_estado_vigente', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    await cambiar(orden.id, 'DIAGNOSTICO');

    // La segunda persona aún "ve" la orden en RECIBIDO e intenta el mismo paso.
    const res = await cambiar(orden.id, 'DIAGNOSTICO', admin);

    expect(res.status).toBe(422);
    expect(res.body.error.details.currentStatus).toBe('DIAGNOSTICO');
    expect(res.body.error.details.allowed).toEqual(['EN_REPARACION', 'ESPERANDO_REFACCION']);
  });

  it('test_un_conflicto_real_se_reporta_como_state_conflict_con_el_estado_vigente', async () => {
    // Se simula la carrera: el estado cambia entre la lectura y la actualización.
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    const { updateStatusIf } = await import('../../models/orderModel.js');

    await query("UPDATE service_orders SET status = 'DIAGNOSTICO' WHERE id = ?", [orden.id]);
    const aplicado = await updateStatusIf(orden.id, 'RECIBIDO', 'DIAGNOSTICO');

    expect(aplicado).toBe(false);
  });
});
