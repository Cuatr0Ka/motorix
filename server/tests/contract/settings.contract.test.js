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

const FUENTES = ['STORED', 'ENV', 'DEFAULT'];

describe('contrato de GET y PUT /api/settings', () => {
  it('test_get_cumple_la_forma_del_contrato', async () => {
    const res = await request(app).get('/api/settings').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body)).toEqual(['data']);
    expect(Object.keys(res.body.data).sort()).toEqual(['maintenance', 'shop', 'sources']);
    expect(Object.keys(res.body.data.shop).sort()).toEqual(['address', 'name', 'phone']);
    expect(Object.keys(res.body.data.maintenance).sort()).toEqual(['warnDays', 'warnKm']);
    expect(Number.isInteger(res.body.data.maintenance.warnDays)).toBe(true);
    expect(Number.isInteger(res.body.data.maintenance.warnKm)).toBe(true);
    expect(Object.keys(res.body.data.sources).sort()).toEqual([
      'maintenance.warn_days',
      'maintenance.warn_km',
      'shop.address',
      'shop.name',
      'shop.phone',
    ]);
    for (const fuente of Object.values(res.body.data.sources)) expect(FUENTES).toContain(fuente);
  });

  it('test_put_devuelve_el_mismo_cuerpo_que_get_con_los_valores_nuevos', async () => {
    const res = await request(app)
      .put('/api/settings')
      .set(auth(admin.token))
      .send({ shop: { name: 'Taller Contrato' }, maintenance: { warnKm: 750 } });

    expect(res.status).toBe(200);
    expect(res.body.data.shop.name).toBe('Taller Contrato');
    expect(res.body.data.maintenance.warnKm).toBe(750);
    expect(Object.keys(res.body.data).sort()).toEqual(['maintenance', 'shop', 'sources']);
    expect(res.body.data.sources['shop.name']).toBe('STORED');
    expect(res.body.data.sources['maintenance.warn_km']).toBe('STORED');
  });

  it('test_los_errores_de_validacion_traen_el_detalle_por_campo', async () => {
    const res = await request(app).put('/api/settings').set(auth(admin.token)).send({ shop: { name: '' } });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(Array.isArray(res.body.error.details)).toBe(true);
    expect(res.body.error.details[0]).toHaveProperty('field');
    expect(res.body.error.details[0]).toHaveProperty('message');
  });

  it('test_un_campo_desconocido_se_rechaza', async () => {
    const res = await request(app).put('/api/settings').set(auth(admin.token)).send({ shop: { name: 'Taller', extra: 1 } });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).get('/api/settings');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });
});
