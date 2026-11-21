import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
});

describe('contrato de /api/terms', () => {
  it('test_get_current_tiene_la_forma_del_contrato', async () => {
    const res = await request(app).get('/api/terms/current').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body.data).sort()).toEqual(['accepted', 'body', 'id', 'publishedAt', 'title', 'version']);
    expect(res.body.data).toMatchObject({ version: '1.0', accepted: true, title: expect.any(String), body: expect.any(String) });
    expect(res.body.data.publishedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('test_post_accept_tiene_la_forma_del_contrato_y_valida_el_cuerpo', async () => {
    const usuario = await createUserWithToken('MECHANIC', { acceptTerms: false });
    const { id } = (await request(app).get('/api/terms/current').set(auth(usuario.token))).body.data;

    const res = await request(app).post('/api/terms/accept').set(auth(usuario.token)).send({ versionId: id });
    expect(res.status).toBe(200);
    expect(Object.keys(res.body.data).sort()).toEqual(['acceptedAt', 'version', 'versionId']);

    for (const cuerpo of [{}, { versionId: 'uno' }, { versionId: 0 }, { versionId: id, otro: 1 }]) {
      const mala = await request(app).post('/api/terms/accept').set(auth(usuario.token)).send(cuerpo);
      expect(mala.status).toBe(400);
      expect(mala.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_get_acceptances_tiene_data_y_meta_con_pending_y_version', async () => {
    const res = await request(app).get('/api/terms/acceptances').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body.meta).sort()).toEqual(['page', 'pageSize', 'pending', 'total', 'version']);
    expect(res.body.data[0]).toMatchObject({ userId: admin.id, username: admin.username });
  });

  it('test_sin_token_401_y_roles_distintos_de_admin_403_en_acceptances', async () => {
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const mecanico = await createUserWithToken('MECHANIC');

    for (const ruta of ['/api/terms/current', '/api/terms/acceptances']) expect((await request(app).get(ruta)).status).toBe(401);
    expect((await request(app).post('/api/terms/accept').send({ versionId: 1 })).status).toBe(401);
    for (const u of [recepcion, mecanico]) expect((await request(app).get('/api/terms/acceptances').set(auth(u.token))).status).toBe(403);
  });
});
