import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;

beforeAll(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
});

const enviar = (body, token = admin.token) =>
  request(app).post('/api/notifications/read').set(auth(token)).send(body);

describe('contrato de POST /api/notifications/read', () => {
  it('test_responde_con_la_forma_marked_y_unread', async () => {
    const res = await enviar({ keys: ['MAINT_OVERDUE:99999'] });

    expect(res.status).toBe(200);
    expect(Object.keys(res.body)).toEqual(['data']);
    expect(Object.keys(res.body.data).sort()).toEqual(['marked', 'unread']);
    expect(Number.isInteger(res.body.data.marked)).toBe(true);
    expect(Number.isInteger(res.body.data.unread)).toBe(true);
  });

  it('test_un_arreglo_vacio_responde_400_con_el_detalle_por_campo', async () => {
    const res = await enviar({ keys: [] });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(Array.isArray(res.body.error.details)).toBe(true);
  });

  it('test_mas_de_cincuenta_claves_responde_400', async () => {
    const keys = Array.from({ length: 51 }, (_, i) => `STOCK_LOW:${i + 1}`);

    const res = await enviar({ keys });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_una_clave_mal_formada_responde_400', async () => {
    for (const keys of [['mala'], ['STOCK_LOW:abc'], [42], "STOCK_LOW:1' OR '1'='1"]) {
      const res = await enviar({ keys });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_un_cuerpo_sin_claves_o_con_campos_extra_responde_400', async () => {
    expect((await enviar({})).status).toBe(400);
    expect((await enviar({ keys: ['STOCK_LOW:1'], nota: 'x' })).status).toBe(400);
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).post('/api/notifications/read').send({ keys: ['STOCK_LOW:1'] });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });
});
