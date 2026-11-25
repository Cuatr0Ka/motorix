import express from 'express';
import request from 'supertest';
import { errorHandler } from '../../middlewares/errorHandler.js';
import { createLoginRateLimit } from '../../middlewares/loginRateLimit.js';

describe('límite de intentos de inicio de sesión por IP', () => {
  const build = (max) => {
    const app = express();
    app.post('/login', createLoginRateLimit({ max, skip: () => false }), (req, res) => res.json({ ok: true }));
    app.use(errorHandler);
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

describe('ventana del límite de inicio de sesión', () => {
  test('test_vuelve_a_permitir_intentos_al_vencer_la_ventana', async () => {
    let ahora = 0;
    const app = express();
    app.post('/login', createLoginRateLimit({ max: 1, windowMs: 1000, skip: () => false, now: () => ahora }), (req, res) =>
      res.json({ ok: true }),
    );
    app.use((error, req, res, next) => res.status(error.status ?? 500).json({ error: { code: error.code } }));

    await request(app).post('/login').expect(200);
    await request(app).post('/login').expect(429);
    ahora = 1001;
    await request(app).post('/login').expect(200);
  });
});
