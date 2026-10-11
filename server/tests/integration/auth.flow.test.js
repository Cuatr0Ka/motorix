import request from 'supertest';
import jwt from 'jsonwebtoken';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUser, resetDatabase, TEST_PASSWORD } from '../helpers/factories.js';

const app = createApp();

const login = (identifier, password = TEST_PASSWORD) =>
  request(app).post('/api/auth/login').send({ identifier, password });

beforeEach(resetDatabase);

describe('flujo de inicio de sesión', () => {
  it('test_inicia_sesion_con_usuario_y_con_correo_usando_la_misma_contrasena', async () => {
    const user = await createUser({ username: 'recepcion', email: 'recepcion@prueba.local' });

    const porUsuario = await login('recepcion');
    const porCorreo = await login('recepcion@prueba.local');

    expect(porUsuario.status).toBe(200);
    expect(porCorreo.status).toBe(200);
    expect(porUsuario.body.data.user.id).toBe(user.id);
    expect(porCorreo.body.data.user.id).toBe(user.id);
  });

  it('test_el_acceso_no_distingue_mayusculas_en_usuario_ni_correo', async () => {
    await createUser({ username: 'Admin', email: 'Admin@Prueba.local', role: 'ADMIN' });

    expect((await login('admin')).status).toBe(200);
    expect((await login('ADMIN@prueba.LOCAL')).status).toBe(200);
  });

  it('test_acepta_espacios_al_inicio_y_al_final_del_identificador', async () => {
    await createUser({ username: 'mecanico1', role: 'MECHANIC' });

    expect((await login('  mecanico1  ')).status).toBe(200);
  });

  it('test_contrasena_incorrecta_y_cuenta_inexistente_dan_el_mismo_mensaje_generico', async () => {
    await createUser({ username: 'ana' });

    const incorrecta = await login('ana', 'Incorrecta1');
    const inexistente = await login('nadie', TEST_PASSWORD);

    expect(incorrecta.status).toBe(401);
    expect(inexistente.status).toBe(401);
    expect(incorrecta.body).toEqual(inexistente.body);
  });

  it('test_rechaza_una_cuenta_desactivada_con_el_mismo_mensaje_generico', async () => {
    await createUser({ username: 'baja', active: 0 });

    const res = await login('baja');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('test_rechaza_un_token_vencido', async () => {
    const user = await createUser();
    const vencido = jwt.sign({ sub: String(user.id) }, process.env.JWT_SECRET, { expiresIn: -10 });

    const res = await request(app).get('/api/auth/me').set(auth(vencido));

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('test_rechaza_un_token_firmado_con_otro_secreto', async () => {
    const user = await createUser();
    const falso = jwt.sign({ sub: String(user.id) }, 'otro-secreto-distinto', { expiresIn: 60 });

    const res = await request(app).get('/api/auth/me').set(auth(falso));

    expect(res.status).toBe(401);
  });
});

describe('efecto inmediato de cambios en una sesión abierta', () => {
  it('test_el_cambio_de_rol_rige_en_la_siguiente_peticion_sin_reiniciar_sesion', async () => {
    const user = await createUser({ username: 'ana', role: 'RECEPTIONIST' });
    const { body } = await login('ana');
    const token = body.data.token;

    expect((await request(app).get('/api/auth/me').set(auth(token))).body.data.role).toBe('RECEPTIONIST');

    await query("UPDATE users SET role = 'MECHANIC' WHERE id = ?", [user.id]);

    expect((await request(app).get('/api/auth/me').set(auth(token))).body.data.role).toBe('MECHANIC');
  });

  it('test_la_desactivacion_rechaza_la_siguiente_peticion_aunque_el_token_siga_vigente', async () => {
    const user = await createUser({ username: 'ana' });
    const { body } = await login('ana');
    const token = body.data.token;

    await query('UPDATE users SET active = 0 WHERE id = ?', [user.id]);

    const res = await request(app).get('/api/auth/me').set(auth(token));
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });
});

describe('bloqueo por intentos fallidos', () => {
  it('test_bloquea_la_cuenta_tras_5_fallos_consecutivos_aun_con_la_contrasena_correcta', async () => {
    await createUser({ username: 'ana' });

    for (let i = 0; i < 5; i += 1) {
      const res = await login('ana', 'Incorrecta1');
      expect(res.status).toBe(i < 4 ? 401 : 423);
    }

    const conClaveCorrecta = await login('ana');
    expect(conClaveCorrecta.status).toBe(423);
    expect(conClaveCorrecta.body.error.code).toBe('ACCOUNT_LOCKED');
    expect(conClaveCorrecta.body.error.details.retryAfterSeconds).toBeGreaterThan(0);
    expect(conClaveCorrecta.body.error.details.retryAfterSeconds).toBeLessThanOrEqual(900);
  });

  it('test_un_acceso_correcto_reinicia_el_contador_de_fallos', async () => {
    await createUser({ username: 'ana' });

    for (let i = 0; i < 4; i += 1) await login('ana', 'Incorrecta1');
    expect((await login('ana')).status).toBe(200);

    // Si el contador no se hubiera reiniciado, este fallo bloquearía la cuenta (sería el 5.º).
    expect((await login('ana', 'Incorrecta1')).status).toBe(401);
    expect((await login('ana')).status).toBe(200);
  });

  it('test_el_bloqueo_vence_pasados_15_minutos', async () => {
    const user = await createUser({ username: 'ana' });
    for (let i = 0; i < 5; i += 1) await login('ana', 'Incorrecta1');
    expect((await login('ana')).status).toBe(423);

    await query('UPDATE users SET locked_until = NOW() - INTERVAL 1 SECOND WHERE id = ?', [user.id]);

    expect((await login('ana')).status).toBe(200);
  });
});
