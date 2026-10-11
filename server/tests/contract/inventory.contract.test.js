import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let parte;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  parte = await createPart(admin.id, { code: 'INV-001', stock: 10, minStock: 3 });
});

describe('POST /api/parts/:id/movements (contrato)', () => {
  it('test_la_entrada_responde_201_con_movimiento_y_refaccion', async () => {
    const res = await request(app)
      .post(`/api/parts/${parte.id}/movements`)
      .set(auth(admin.token))
      .send({ type: 'IN', quantity: 4, reason: 'Compra a proveedor' });

    expect(res.status).toBe(201);
    expect(res.body.data.movement).toMatchObject({
      id: expect.any(Number),
      type: 'IN',
      quantity: 4,
      reason: 'Compra a proveedor',
      createdAt: expect.any(String),
      order: null,
      createdBy: { id: admin.id },
    });
    expect(res.body.data.part).toMatchObject({ id: parte.id, stock: 14, stockStatus: 'SUFICIENTE' });
  });

  it('test_el_ajuste_responde_201_y_el_movimiento_lleva_la_diferencia', async () => {
    const res = await request(app)
      .post(`/api/parts/${parte.id}/movements`)
      .set(auth(admin.token))
      .send({ type: 'ADJUSTMENT', countedQuantity: 2, reason: 'Conteo físico de octubre' });

    expect(res.status).toBe(201);
    expect(res.body.data.movement).toMatchObject({ type: 'ADJUSTMENT', quantity: -8 });
    expect(res.body.data.part).toMatchObject({ stock: 2, stockStatus: 'BAJO' });
  });

  it('test_un_ajuste_sin_diferencia_responde_422', async () => {
    const res = await request(app)
      .post(`/api/parts/${parte.id}/movements`)
      .set(auth(admin.token))
      .send({ type: 'ADJUSTMENT', countedQuantity: 10, reason: 'Sin cambios aparentes' });

    expect(res.status).toBe(422);
    expect(res.body.error).toMatchObject({ code: 'NO_ADJUSTMENT_DIFFERENCE', message: expect.any(String) });
  });

  it('test_una_entrada_a_una_inactiva_responde_409_part_inactive', async () => {
    await request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ active: false });

    const res = await request(app).post(`/api/parts/${parte.id}/movements`).set(auth(admin.token)).send({ type: 'IN', quantity: 1 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PART_INACTIVE');
  });

  it('test_un_cuerpo_invalido_responde_400_con_detalles_por_campo', async () => {
    const res = await request(app).post(`/api/parts/${parte.id}/movements`).set(auth(admin.token)).send({ type: 'IN', quantity: 0 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details[0]).toMatchObject({ field: 'quantity', message: expect.any(String) });
  });
});

describe('GET /api/parts/:id/movements (contrato)', () => {
  it('test_responde_200_con_la_lista_y_meta', async () => {
    const res = await request(app).get(`/api/parts/${parte.id}/movements`).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ type: 'IN', quantity: 10, order: null });
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
  });
});
