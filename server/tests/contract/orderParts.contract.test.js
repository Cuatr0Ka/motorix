import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createOrder, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;
let parte;

const linea = {
  id: expect.any(Number),
  partId: expect.any(Number),
  code: expect.any(String),
  name: expect.any(String),
  unit: expect.any(String),
  quantity: expect.any(Number),
};

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPC-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  parte = await createPart(admin.id, { code: 'OPC-REF', stock: 5, minStock: 3 });
});

describe('POST /api/orders/:id/parts (contrato)', () => {
  it('test_responde_201_con_la_linea_y_la_refaccion_actualizada', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });

    expect(res.status).toBe(201);
    expect(res.body.data.item).toEqual({ ...linea, quantity: 2 });
    expect(res.body.data.part).toMatchObject({ id: parte.id, stock: 3, stockStatus: 'BAJO' });
  });

  it('test_stock_insuficiente_responde_409_con_el_disponible', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 9 });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'INSUFFICIENT_STOCK', details: { available: 5, requested: 9 } });
  });

  it('test_un_cuerpo_invalido_responde_400_con_detalles_por_campo', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ quantity: 0 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['partId', 'quantity']);
  });
});

describe('PATCH y DELETE /api/orders/:id/parts/:lineId (contrato)', () => {
  let lineId;

  beforeEach(async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });
    lineId = res.body.data.item.id;
  });

  it('test_patch_responde_200_con_la_linea_corregida', async () => {
    const res = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(admin.token)).send({ quantity: 4 });

    expect(res.status).toBe(200);
    expect(res.body.data.item).toEqual({ ...linea, quantity: 4 });
    expect(res.body.data.part.stock).toBe(1);
  });

  it('test_delete_responde_200_con_deleted_y_la_refaccion', async () => {
    const res = await request(app).delete(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ deleted: true, part: { id: parte.id, stock: 5 } });
  });

  it('test_un_identificador_de_linea_invalido_responde_400', async () => {
    const res = await request(app).delete(`/api/orders/${orden.id}/parts/abc`).set(auth(mecanico.token));

    expect(res.status).toBe(400);
  });

  it('test_recepcion_recibe_403_y_sin_sesion_401', async () => {
    const sinPermiso = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(recepcion.token)).send({ quantity: 1 });
    const sinSesion = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).send({ quantity: 1 });

    expect(sinPermiso.status).toBe(403);
    expect(sinSesion.status).toBe(401);
  });
});

describe('GET /api/orders/:id (contrato ampliado)', () => {
  it('test_incluye_parts_y_service_mileage_para_todos_los_roles', async () => {
    await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 1 });

    for (const user of [admin, recepcion, mecanico]) {
      const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(user.token));
      expect(res.status).toBe(200);
      expect(res.body.data.parts).toEqual([{ ...linea, quantity: 1 }]);
      expect(res.body.data).toHaveProperty('serviceMileage', null);
      expect(res.body.data).toHaveProperty('maintenance', null);
    }
  });
});
