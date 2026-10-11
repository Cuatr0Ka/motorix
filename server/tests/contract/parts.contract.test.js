import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let mecanico;
let parte;

const objetoRefaccion = {
  id: expect.any(Number),
  code: expect.any(String),
  name: expect.any(String),
  unit: expect.any(String),
  stock: expect.any(Number),
  minStock: expect.any(Number),
  active: expect.any(Boolean),
  stockStatus: expect.stringMatching(/^(SUFICIENTE|BAJO|AGOTADO)$/),
};

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
  parte = await createPart(admin.id, { code: 'CTR-001', name: 'Refacción de contrato', unit: 'juego', stock: 6, minStock: 2 });
});

describe('GET /api/parts (contrato)', () => {
  it('test_el_administrador_recibe_el_objeto_completo_con_meta', async () => {
    const res = await request(app).get('/api/parts').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data[0]).toMatchObject(objetoRefaccion);
    expect(res.body.data[0]).toHaveProperty('description');
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
  });

  it('test_el_mecanico_recibe_solo_la_proyeccion_reducida', async () => {
    const res = await request(app).get('/api/parts').set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data[0]).toEqual({ id: parte.id, code: 'CTR-001', name: 'Refacción de contrato', unit: 'juego', stock: 6 });
  });

  it('test_rechaza_parametros_invalidos_con_400', async () => {
    const res = await request(app).get('/api/parts?stockStatus=MUCHO').set(auth(admin.token));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_exige_sesion', async () => {
    expect((await request(app).get('/api/parts')).status).toBe(401);
  });
});

describe('POST/PATCH/GET /api/parts (contrato)', () => {
  it('test_post_responde_201_con_la_refaccion', async () => {
    const res = await request(app)
      .post('/api/parts')
      .set(auth(admin.token))
      .send({ code: 'nuevo-01', name: 'Nueva pieza', unit: 'pieza', minStock: 1, initialStock: 4 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ ...objetoRefaccion, code: 'NUEVO-01', stock: 4, active: true });
  });

  it('test_post_con_codigo_repetido_responde_409_part_code_taken', async () => {
    const res = await request(app)
      .post('/api/parts')
      .set(auth(admin.token))
      .send({ code: 'CTR-001', name: 'Otra', unit: 'pieza', minStock: 0, initialStock: 0 });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'PART_CODE_TAKEN', message: expect.any(String) });
  });

  it('test_patch_responde_200_con_la_refaccion_actualizada', async () => {
    const res = await request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ minStock: 9 });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ ...objetoRefaccion, minStock: 9, stockStatus: 'BAJO' });
  });

  it('test_get_por_id_incluye_los_movimientos_con_la_forma_del_contrato', async () => {
    const res = await request(app).get(`/api/parts/${parte.id}`).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject(objetoRefaccion);
    expect(res.body.data.movements[0]).toMatchObject({
      id: expect.any(Number),
      type: 'IN',
      quantity: 6,
      reason: 'Stock inicial',
      createdAt: expect.any(String),
      order: null,
      createdBy: { id: admin.id, name: expect.any(String) },
    });
  });

  it('test_un_identificador_invalido_responde_400', async () => {
    const res = await request(app).get('/api/parts/abc').set(auth(admin.token));

    expect(res.status).toBe(400);
  });
});

describe('GET /api/parts/alerts (contrato)', () => {
  it('test_responde_200_con_count_out_of_stock_e_items', async () => {
    await createPart(admin.id, { code: 'ALR-001', stock: 1, minStock: 4 });
    await createPart(admin.id, { code: 'ALR-002', stock: 0, minStock: 4 });

    const res = await request(app).get('/api/parts/alerts').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ count: 2, outOfStock: 1 });
    expect(res.body.data.items).toHaveLength(2);
    expect(res.body.data.items[0]).toMatchObject({ ...objetoRefaccion, code: 'ALR-002', stockStatus: 'AGOTADO' });
  });

  it('test_el_mecanico_recibe_403', async () => {
    const res = await request(app).get('/api/parts/alerts').set(auth(mecanico.token));

    expect(res.status).toBe(403);
  });
});
