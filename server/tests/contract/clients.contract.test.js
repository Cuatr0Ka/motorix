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

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('GET /api/clients (contrato)', () => {
  it('test_lista_clientes_con_conteo_de_vehiculos_y_metadatos_de_paginacion', async () => {
    const cliente = await createClient({ name: 'Ana López', phone: '5511112222', email: 'ana@x.local' });
    await createVehicle(cliente.id);
    await createVehicle(cliente.id);

    const res = await request(app).get('/api/clients').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data[0]).toEqual({
      id: cliente.id,
      name: 'Ana López',
      phone: '5511112222',
      email: 'ana@x.local',
      address: null,
      vehicleCount: 2,
      createdAt: expect.any(String),
    });
  });

  it('test_responde_401_sin_token', async () => {
    expect((await request(app).get('/api/clients')).status).toBe(401);
  });

  it('test_responde_400_con_pagina_invalida', async () => {
    const res = await request(app).get('/api/clients?page=0').set(auth(recepcion.token));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_el_mecanico_puede_consultar_el_listado', async () => {
    expect((await request(app).get('/api/clients').set(auth(mecanico.token))).status).toBe(200);
  });
});

describe('POST /api/clients (contrato)', () => {
  it('test_crea_un_cliente_y_devuelve_201_con_sus_datos', async () => {
    const res = await request(app)
      .post('/api/clients')
      .set(auth(recepcion.token))
      .send({ name: '  Luis Pérez ', phone: '55 1234 5678', email: 'LUIS@Correo.com', address: 'Calle 1' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      name: 'Luis Pérez',
      phone: '55 1234 5678',
      email: 'luis@correo.com',
      address: 'Calle 1',
      vehicles: [],
    });
    expect(res.body.data.id).toEqual(expect.any(Number));
  });

  it('test_responde_400_con_detalles_por_campo_si_faltan_datos_obligatorios', async () => {
    const res = await request(app).post('/api/clients').set(auth(recepcion.token)).send({ email: 'no-es-correo' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['email', 'name', 'phone']);
  });

  it('test_responde_403_para_el_mecanico', async () => {
    const res = await request(app)
      .post('/api/clients')
      .set(auth(mecanico.token))
      .send({ name: 'Luis Pérez', phone: '5512345678' });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_responde_401_sin_token', async () => {
    expect((await request(app).post('/api/clients').send({})).status).toBe(401);
  });
});

describe('GET /api/clients/:id (contrato)', () => {
  it('test_devuelve_el_cliente_con_sus_vehiculos', async () => {
    const cliente = await createClient();
    const vehiculo = await createVehicle(cliente.id, { currentMileage: 1500 });

    const res = await request(app).get(`/api/clients/${cliente.id}`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(cliente.id);
    expect(res.body.data.vehicles).toEqual([
      {
        id: vehiculo.id,
        brand: 'Nissan',
        model: 'Versa',
        year: 2020,
        licensePlate: vehiculo.licensePlate,
        currentMileage: 1500,
      },
    ]);
  });

  it('test_responde_404_si_el_cliente_no_existe', async () => {
    const res = await request(app).get('/api/clients/999999').set(auth(recepcion.token));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_responde_400_si_el_id_no_es_numerico', async () => {
    expect((await request(app).get('/api/clients/abc').set(auth(recepcion.token))).status).toBe(400);
  });
});
