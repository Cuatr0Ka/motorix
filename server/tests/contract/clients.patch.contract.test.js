import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClient,
  createUserWithToken,
  createVehicle,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let cliente;

const patch = (id, body, token = recepcion.token) =>
  request(app).patch(`/api/clients/${id}`).set(auth(token)).send(body);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  cliente = await createClient({ name: 'Ana Morales', phone: '5511112222', email: 'ana@x.local', address: 'Calle 1' });
});

describe('PATCH /api/clients/:id (contrato)', () => {
  it('test_actualiza_los_campos_enviados_y_conserva_los_demas', async () => {
    const res = await patch(cliente.id, { phone: '5599998888' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: cliente.id,
      name: 'Ana Morales',
      phone: '5599998888',
      email: 'ana@x.local',
      address: 'Calle 1',
      vehicles: [],
    });
  });

  it('test_devuelve_el_cliente_con_sus_vehiculos', async () => {
    const vehiculo = await createVehicle(cliente.id);

    const res = await patch(cliente.id, { name: '  Ana María Morales ' });

    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Ana María Morales');
    expect(res.body.data.vehicles.map((v) => v.id)).toEqual([vehiculo.id]);
  });

  it('test_responde_400_con_detalles_por_campo_ante_datos_invalidos', async () => {
    const res = await patch(cliente.id, { name: '   ', phone: 'abc', email: 'sin-arroba' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['email', 'name', 'phone']);
  });

  it('test_responde_400_si_el_cuerpo_viene_vacio', async () => {
    const res = await patch(cliente.id, {});

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_responde_403_para_el_mecanico', async () => {
    const res = await patch(cliente.id, { phone: '5599998888' }, mecanico.token);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_responde_401_sin_token', async () => {
    const res = await request(app).patch(`/api/clients/${cliente.id}`).send({ phone: '5599998888' });

    expect(res.status).toBe(401);
  });

  it('test_responde_404_si_el_cliente_no_existe', async () => {
    const res = await patch(999999, { phone: '5599998888' });

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_responde_400_si_el_id_no_es_numerico', async () => {
    expect((await patch('abc', { phone: '5599998888' })).status).toBe(400);
  });
});
