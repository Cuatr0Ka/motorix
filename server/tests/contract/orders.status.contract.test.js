import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let vehiculo;

const cambiar = (id, status, user = mecanico) => request(app).post(`/api/orders/${id}/status`).set(auth(user.token)).send({ status });

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'STC-001-A' }));
});

describe('POST /api/orders/:id/status (contrato)', () => {
  it('test_cambia_el_estado_y_devuelve_el_detalle_con_un_registro_mas_en_el_historial', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const res = await cambiar(orden.id, 'DIAGNOSTICO');

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id: orden.id, status: 'DIAGNOSTICO', allowedTransitions: ['EN_REPARACION', 'ESPERANDO_REFACCION'] });
    expect(res.body.data.statusHistory).toHaveLength(2);
    expect(res.body.data.statusHistory[1]).toEqual({
      fromStatus: 'RECIBIDO',
      toStatus: 'DIAGNOSTICO',
      changedBy: { id: mecanico.id, name: expect.any(String) },
      changedAt: expect.any(String),
    });
  });

  it('test_rechaza_un_estado_desconocido_o_ausente_con_400', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const invalido = await cambiar(orden.id, 'INVENTADO');
    const ausente = await request(app).post(`/api/orders/${orden.id}/status`).set(auth(mecanico.token)).send({});

    expect(invalido.status).toBe(400);
    expect(invalido.body.error.code).toBe('VALIDATION_ERROR');
    expect(ausente.status).toBe(400);
  });

  it('test_una_transicion_fuera_de_la_secuencia_responde_422_con_las_permitidas', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const res = await cambiar(orden.id, 'TERMINADO');

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INVALID_TRANSITION');
    expect(res.body.error.details).toEqual({ currentStatus: 'RECIBIDO', allowed: ['DIAGNOSTICO'] });
    expect(res.body.error.message).toContain('Diagnóstico');
  });

  it('test_una_orden_sin_mecanico_responde_422_orden_sin_asignar', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);
    const admin = await createUserWithToken('ADMIN');

    const res = await cambiar(orden.id, 'DIAGNOSTICO', admin);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ORDER_UNASSIGNED');
  });

  it('test_el_rol_sin_permiso_recibe_403', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const res = await cambiar(orden.id, 'DIAGNOSTICO', recepcion);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_el_mecanico_ajeno_recibe_404_y_la_orden_inexistente_404', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    const otro = await createUserWithToken('MECHANIC');

    expect((await cambiar(orden.id, 'DIAGNOSTICO', otro)).status).toBe(404);
    expect((await cambiar(999999, 'DIAGNOSTICO')).status).toBe(404);
  });

  it('test_una_orden_entregada_responde_409_solo_lectura', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id, status: 'ENTREGADO' });

    const res = await cambiar(orden.id, 'TERMINADO', recepcion);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).post('/api/orders/1/status').send({ status: 'DIAGNOSTICO' });

    expect(res.status).toBe(401);
  });
});
