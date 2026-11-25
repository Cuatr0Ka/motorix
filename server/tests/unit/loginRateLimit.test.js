import express from 'express';
import request from 'supertest';
import { createLoginRateLimit } from '../../middlewares/loginRateLimit.js';

describe('límite de intentos de inicio de sesión por IP', () => {
  const build = (max) => {
    const app = express();
    app.post('/login', createLoginRateLimit({ max, skip: () => false }), (req, res) => res.json({ ok: true }));
    return app;
  };

  test('test_responde_429_al_superar_el_maximo_de_intentos', async () => {
    const app = build(2);
    await request(app).post('/login').expect(200);
    await request(app).post('/login').expect(200);
    const res = await request(app).post('/login');
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('TOO_MANY_REQUESTS');
  });

  test('test_no_limita_mientras_no_se_supere_el_maximo', async () => {
    const res = await request(build(5)).post('/login');
    expect(res.status).toBe(200);
  });
});
