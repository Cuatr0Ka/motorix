import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  // Un cambio de configuración deja una fila atribuida al administrador.
  await request(app).put('/api/settings').set(auth(admin.token)).send({ shop: { name: 'Taller Contrato' } });
});

describe('contrato de GET /api/audit-log', () => {
  it('test_la_respuesta_tiene_la_forma_del_contrato_y_el_actor_siempre_trae_el_usuario', async () => {
    const res = await request(app).get('/api/audit-log').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    const fila = res.body.data[0];
    expect(Object.keys(fila).sort()).toEqual(['action', 'actor', 'createdAt', 'entityId', 'entityType', 'id', 'summary']);
    expect(fila.actor).toEqual({ id: admin.id, username: admin.username, name: admin.name });
    expect(fila.createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(fila.action).toBe('SETTINGS_CHANGED');
  });

  it('test_los_filtros_invalidos_responden_validation_error', async () => {
    for (const consulta of ['from=ayer', 'to=2026-13-40', 'userId=abc', 'userId=0', 'action=INVENTADA', 'pageSize=101', 'page=0']) {
      const res = await request(app).get(`/api/audit-log?${consulta}`).set(auth(admin.token));
      expect({ consulta, estado: res.status }).toEqual({ consulta, estado: 400 });
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_sin_token_responde_401', async () => {
    expect((await request(app).get('/api/audit-log')).status).toBe(401);
  });
});
