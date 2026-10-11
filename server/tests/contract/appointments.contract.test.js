import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createAppointment,
  createClientWithVehicle,
  createUserWithToken,
  hoursFromNow,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let cliente;
let vehiculo;

const cuerpoValido = () => ({
  clientId: cliente.id,
  vehicleId: vehiculo.id,
  scheduledAt: hoursFromNow(72).toISOString(),
  reason: 'Cambio de aceite',
  notes: 'Traerá su propio aceite',
});

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'CIT-001-A' }, { name: 'Ana Morales' }));
});

const formaCita = {
  id: expect.any(Number),
  status: expect.any(String),
  scheduledAt: expect.any(String),
  reason: expect.any(String),
  client: expect.objectContaining({ id: expect.any(Number), name: expect.any(String) }),
  vehicle: expect.objectContaining({ id: expect.any(Number), licensePlate: expect.any(String) }),
};

describe('GET /api/appointments (contrato)', () => {
  it('test_lista_citas_con_su_cliente_vehiculo_y_metadatos_de_paginacion', async () => {
    await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await request(app).get('/api/appointments').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ ...formaCita, status: 'PENDIENTE', order: null });
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
  });

  it('test_rechaza_un_filtro_de_estado_invalido_con_400', async () => {
    const res = await request(app).get('/api/appointments?status=INVENTADO').set(auth(recepcion.token));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_sin_token_responde_401_y_el_mecanico_recibe_403', async () => {
    expect((await request(app).get('/api/appointments')).status).toBe(401);
    const res = await request(app).get('/api/appointments').set(auth(mecanico.token));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});

describe('POST /api/appointments (contrato)', () => {
  it('test_crea_una_cita_pendiente_con_201', async () => {
    const res = await request(app).post('/api/appointments').set(auth(recepcion.token)).send(cuerpoValido());

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ ...formaCita, status: 'PENDIENTE', reason: 'Cambio de aceite' });
  });

  it('test_rechaza_datos_invalidos_con_400_y_detalle_por_campo', async () => {
    const res = await request(app)
      .post('/api/appointments')
      .set(auth(recepcion.token))
      .send({ clientId: cliente.id, vehicleId: vehiculo.id, scheduledAt: 'mañana', reason: '   ' });

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['reason', 'scheduledAt']);
  });

  it('test_sin_token_401_y_mecanico_403', async () => {
    expect((await request(app).post('/api/appointments').send(cuerpoValido())).status).toBe(401);
    const res = await request(app).post('/api/appointments').set(auth(mecanico.token)).send(cuerpoValido());
    expect(res.status).toBe(403);
  });
});

describe('GET/PATCH /api/appointments/:id (contrato)', () => {
  it('test_obtiene_el_detalle_y_responde_404_si_no_existe', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const ok = await request(app).get(`/api/appointments/${cita.id}`).set(auth(recepcion.token));
    expect(ok.status).toBe(200);
    expect(ok.body.data).toMatchObject({ ...formaCita, id: cita.id });

    const noExiste = await request(app).get('/api/appointments/999999').set(auth(recepcion.token));
    expect(noExiste.status).toBe(404);
    expect(noExiste.body.error.code).toBe('NOT_FOUND');
  });

  it('test_modifica_una_cita_y_rechaza_un_cuerpo_vacio', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await request(app)
      .patch(`/api/appointments/${cita.id}`)
      .set(auth(recepcion.token))
      .send({ reason: 'Revisión de frenos' });
    expect(res.status).toBe(200);
    expect(res.body.data.reason).toBe('Revisión de frenos');

    const vacio = await request(app).patch(`/api/appointments/${cita.id}`).set(auth(recepcion.token)).send({});
    expect(vacio.status).toBe(400);
  });

  it('test_el_mecanico_recibe_403_en_detalle_y_modificacion', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    expect((await request(app).get(`/api/appointments/${cita.id}`).set(auth(mecanico.token))).status).toBe(403);
    expect(
      (await request(app).patch(`/api/appointments/${cita.id}`).set(auth(mecanico.token)).send({ reason: 'x' })).status,
    ).toBe(403);
  });
});

describe('POST /api/appointments/:id/confirm y /cancel (contrato)', () => {
  it('test_confirma_una_cita_pendiente', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await request(app).post(`/api/appointments/${cita.id}/confirm`).set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('CONFIRMADA');
  });

  it('test_cancela_una_cita_y_devuelve_el_motivo', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    const res = await request(app)
      .post(`/api/appointments/${cita.id}/cancel`)
      .set(auth(recepcion.token))
      .send({ reason: 'El cliente reprogramó' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ status: 'CANCELADA', cancelReason: 'El cliente reprogramó' });
    expect(res.body.data.cancelledAt).toEqual(expect.any(String));
  });

  it('test_el_mecanico_recibe_403_y_sin_token_401', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id);

    for (const accion of ['confirm', 'cancel']) {
      expect((await request(app).post(`/api/appointments/${cita.id}/${accion}`)).status).toBe(401);
      expect((await request(app).post(`/api/appointments/${cita.id}/${accion}`).set(auth(mecanico.token))).status).toBe(403);
    }
  });
});
