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
let vehiculo;

const patch = (id, body, token = recepcion.token) =>
  request(app).patch(`/api/vehicles/${id}`).set(auth(token)).send(body);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  cliente = await createClient({ name: 'Ana Morales', phone: '5511112222' });
  vehiculo = await createVehicle(cliente.id, { currentMileage: 1000 });
});

describe('PATCH /api/vehicles/:id (contrato)', () => {
  it('test_actualiza_los_campos_enviados_y_conserva_los_demas', async () => {
    const res = await patch(vehiculo.id, { color: 'Rojo', currentMileage: 1500 });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: vehiculo.id,
      brand: 'Nissan',
      model: 'Versa',
      color: 'Rojo',
      currentMileage: 1500,
      client: { id: cliente.id, name: 'Ana Morales', phone: '5511112222' },
    });
  });

  it('test_responde_400_con_detalles_por_campo_ante_datos_invalidos', async () => {
    const res = await patch(vehiculo.id, { year: 1800, vin: 'corto' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['vin', 'year']);
  });

  it('test_responde_400_si_el_cuerpo_viene_vacio', async () => {
    const res = await patch(vehiculo.id, {});

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_responde_403_para_el_mecanico', async () => {
    const res = await patch(vehiculo.id, { color: 'Rojo' }, mecanico.token);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_responde_401_sin_token', async () => {
    const res = await request(app).patch(`/api/vehicles/${vehiculo.id}`).send({ color: 'Rojo' });

    expect(res.status).toBe(401);
  });

  it('test_responde_404_si_el_vehiculo_no_existe', async () => {
    const res = await patch(999999, { color: 'Rojo' });

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_responde_400_si_el_id_no_es_numerico', async () => {
    expect((await patch('abc', { color: 'Rojo' })).status).toBe(400);
  });
});
