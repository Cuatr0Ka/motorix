import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createFinishedOrder, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;

beforeAll(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ currentMileage: 1000 }, { phone: '' });
  orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 });
});

describe('contrato de GET /api/client-notices', () => {
  it('test_la_respuesta_cumple_la_forma_del_contrato', async () => {
    const res = await request(app).get('/api/client-notices').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body).sort()).toEqual(['data', 'meta']);
    expect(res.body.meta).toEqual({ total: 1 });
    const fila = res.body.data[0];
    expect(Object.keys(fila).sort()).toEqual(['client', 'description', 'factDate', 'factId', 'folio', 'reason', 'vehicle']);
    expect(fila.reason).toBe('ORDER_READY');
    expect(fila.factId).toBe(orden.id);
    expect(Object.keys(fila.client).sort()).toEqual(['id', 'name', 'phone']);
    expect(Object.keys(fila.vehicle).sort()).toEqual(['brand', 'id', 'licensePlate', 'model']);
  });

  it('test_un_telefono_vacio_llega_como_cadena_vacia', async () => {
    const res = await request(app).get('/api/client-notices').set(auth(admin.token));

    expect(res.body.data[0].client.phone).toBe('');
  });

  it('test_el_mecanico_recibe_403', async () => {
    const res = await request(app).get('/api/client-notices').set(auth(mecanico.token));

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).get('/api/client-notices');

    expect(res.status).toBe(401);
  });
});

describe('contrato de POST /api/client-notices', () => {
  const enviar = (user, body) => request(app).post('/api/client-notices').set(auth(user.token)).send(body);

  it('test_el_mecanico_recibe_403_aunque_el_cuerpo_sea_valido', async () => {
    const res = await enviar(mecanico, { reason: 'ORDER_READY', factId: orden.id });

    expect(res.status).toBe(403);
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).post('/api/client-notices').send({ reason: 'ORDER_READY', factId: orden.id });

    expect(res.status).toBe(401);
  });

  it('test_un_motivo_desconocido_o_un_hecho_invalido_responde_400', async () => {
    for (const body of [
      { reason: 'OTRO', factId: 1 },
      { reason: 'ORDER_READY', factId: 0 },
      { reason: 'ORDER_READY', factId: 'uno' },
      { reason: 'ORDER_READY' },
      {},
    ]) {
      const res = await enviar(recepcion, body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_el_cuerpo_con_una_nota_u_otro_campo_se_rechaza', async () => {
    const res = await enviar(recepcion, { reason: 'ORDER_READY', factId: orden.id, note: 'no contestó' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_crea_con_201_y_la_forma_del_contrato', async () => {
    const res = await enviar(recepcion, { reason: 'ORDER_READY', factId: orden.id });

    expect(res.status).toBe(201);
    expect(Object.keys(res.body)).toEqual(['data']);
    expect(Object.keys(res.body.data).sort()).toEqual(['clientId', 'factId', 'id', 'notifiedAt', 'notifiedBy', 'reason']);
  });
});
