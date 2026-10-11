import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createUser, createUserWithToken, resetDatabase, TEST_PASSWORD } from '../helpers/factories.js';

const app = createApp();

beforeEach(resetDatabase);

describe('POST /api/auth/login (contrato)', () => {
  it('test_devuelve_token_expiracion_y_usuario_sin_datos_sensibles', async () => {
    const user = await createUser({ username: 'recepcion1', role: 'RECEPTIONIST' });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ identifier: 'recepcion1', password: TEST_PASSWORD });

    expect(res.status).toBe(200);
    expect(res.body.data.token).toEqual(expect.any(String));
    expect(res.body.data.expiresIn).toBe(28800);
    expect(res.body.data.user).toEqual({
      id: user.id,
      username: 'recepcion1',
      name: user.name,
      email: user.email,
      role: 'RECEPTIONIST',
    });
    expect(JSON.stringify(res.body)).not.toMatch(/passwordHash|password_hash/);
  });

  it('test_responde_400_si_faltan_campos', async () => {
    const res = await request(app).post('/api/auth/login').send({ identifier: '   ' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['identifier', 'password']);
  });

  it('test_responde_401_con_credenciales_invalidas', async () => {
    await createUser({ username: 'ana' });
    const res = await request(app).post('/api/auth/login').send({ identifier: 'ana', password: 'Incorrecta1' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });
});

describe('GET /api/auth/me (contrato)', () => {
  it('test_devuelve_el_perfil_con_el_rol_vigente', async () => {
    const mecanico = await createUserWithToken('MECHANIC');

    const res = await request(app).get('/api/auth/me').set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id: mecanico.id, role: 'MECHANIC' });
    expect(res.body.data.passwordHash).toBeUndefined();
  });

  it('test_responde_401_sin_token', async () => {
    const res = await request(app).get('/api/auth/me');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('test_responde_401_con_token_invalido', async () => {
    const res = await request(app).get('/api/auth/me').set(auth('token.invalido.xyz'));

    expect(res.status).toBe(401);
  });
});
