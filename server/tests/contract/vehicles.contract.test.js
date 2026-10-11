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

const cuerpoValido = () => ({
  clientId: cliente.id,
  brand: 'Honda',
  model: 'Civic',
  year: 2020,
  licensePlate: 'MNO-345-E',
});

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  cliente = await createClient({ name: 'Ana Morales', phone: '5511112222' });
});

describe('GET /api/vehicles (contrato)', () => {
  it('test_lista_vehiculos_con_su_propietario_y_metadatos_de_paginacion', async () => {
    const vehiculo = await createVehicle(cliente.id, {
      vin: '2HGFC2F59LH345678',
      color: 'Azul',
      currentMileage: 51200,
    });

    const res = await request(app).get('/api/vehicles').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data[0]).toEqual({
      id: vehiculo.id,
      brand: 'Nissan',
      model: 'Versa',
      year: 2020,
      licensePlate: vehiculo.licensePlate,
      vin: '2HGFC2F59LH345678',
      color: 'Azul',
      currentMileage: 51200,
      client: { id: cliente.id, name: 'Ana Morales' },
    });
  });

  it('test_responde_401_sin_token', async () => {
    expect((await request(app).get('/api/vehicles')).status).toBe(401);
  });

  it('test_responde_400_con_filtro_de_cliente_invalido', async () => {
    const res = await request(app).get('/api/vehicles?clientId=abc').set(auth(recepcion.token));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_el_mecanico_puede_consultar_el_listado', async () => {
    expect((await request(app).get('/api/vehicles').set(auth(mecanico.token))).status).toBe(200);
  });
});

describe('POST /api/vehicles (contrato)', () => {
  it('test_crea_un_vehiculo_y_devuelve_201_con_el_propietario', async () => {
    const res = await request(app)
      .post('/api/vehicles')
      .set(auth(recepcion.token))
      .send({ ...cuerpoValido(), licensePlate: '  mno-345-e ', vin: '2hgfc2f59lh345678', currentMileage: 1200 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      brand: 'Honda',
      model: 'Civic',
      year: 2020,
      licensePlate: 'MNO-345-E',
      vin: '2HGFC2F59LH345678',
      color: null,
      currentMileage: 1200,
      client: { id: cliente.id, name: 'Ana Morales', phone: '5511112222' },
    });
  });

  it('test_responde_400_con_detalles_por_campo_si_faltan_datos_obligatorios', async () => {
    const res = await request(app).post('/api/vehicles').set(auth(recepcion.token)).send({});

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual([
      'brand',
      'clientId',
      'licensePlate',
      'model',
      'year',
    ]);
  });

  it('test_responde_403_para_el_mecanico', async () => {
    const res = await request(app).post('/api/vehicles').set(auth(mecanico.token)).send(cuerpoValido());

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_responde_401_sin_token', async () => {
    expect((await request(app).post('/api/vehicles').send({})).status).toBe(401);
  });
});

describe('GET /api/vehicles/:id (contrato)', () => {
  it('test_devuelve_el_vehiculo_con_los_datos_de_su_propietario', async () => {
    const vehiculo = await createVehicle(cliente.id);

    const res = await request(app).get(`/api/vehicles/${vehiculo.id}`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(vehiculo.id);
    expect(res.body.data.client).toEqual({ id: cliente.id, name: 'Ana Morales', phone: '5511112222' });
  });

  it('test_responde_404_si_el_vehiculo_no_existe', async () => {
    const res = await request(app).get('/api/vehicles/999999').set(auth(recepcion.token));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_responde_400_si_el_id_no_es_numerico', async () => {
    expect((await request(app).get('/api/vehicles/abc').set(auth(recepcion.token))).status).toBe(400);
  });
});
