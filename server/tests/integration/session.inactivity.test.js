import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { TEST_PASSWORD, auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let usuario;

const ponerInactividad = (segundos) =>
  query('UPDATE users SET last_activity_at = NOW() - INTERVAL ? SECOND WHERE id = ?', [segundos, usuario.id]);
const actividad = async () => (await query('SELECT last_activity_at FROM users WHERE id = ?', [usuario.id]))[0].last_activity_at;
const yo = () => request(app).get('/api/auth/me').set(auth(usuario.token));

beforeEach(async () => {
  await resetDatabase();
  usuario = await createUserWithToken('RECEPTIONIST');
});

describe('cierre de sesión por inactividad (US10, FR-016)', () => {
  it('test_una_peticion_tras_mas_de_30_minutos_sin_actividad_responde_401_session_inactive', async () => {
    await ponerInactividad(31 * 60);

    const res = await yo();

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('SESSION_INACTIVE');
    expect(res.body.error.message).toBe('Tu sesión se cerró por inactividad. Inicia sesión de nuevo.');
  });

  it('test_con_actividad_reciente_la_sesion_sigue_y_se_renueva', async () => {
    await ponerInactividad(5 * 60);

    expect((await yo()).status).toBe(200);

    const [fila] = await query('SELECT TIMESTAMPDIFF(SECOND, last_activity_at, NOW()) AS idle FROM users WHERE id = ?', [usuario.id]);
    expect(Number(fila.idle)).toBeLessThan(5);
  });

  it('test_la_actividad_se_renueva_como_maximo_una_vez_por_minuto', async () => {
    await ponerInactividad(10); // menos de un minuto: no se vuelve a escribir
    await yo();

    const [fila] = await query('SELECT TIMESTAMPDIFF(SECOND, last_activity_at, NOW()) AS idle FROM users WHERE id = ?', [usuario.id]);
    expect(Number(fila.idle)).toBeGreaterThanOrEqual(10);
  });

  it('test_un_valor_nulo_se_trata_como_activa_y_se_fija', async () => {
    await query('UPDATE users SET last_activity_at = NULL WHERE id = ?', [usuario.id]);

    expect((await yo()).status).toBe(200);
    expect(await actividad()).not.toBeNull();
  });

  it('test_el_inicio_de_sesion_fija_la_actividad_y_una_cuenta_inactiva_por_tiempo_puede_volver_a_entrar', async () => {
    await ponerInactividad(2 * 3600);
    expect((await yo()).status).toBe(401);

    const login = await request(app).post('/api/auth/login').send({ identifier: usuario.username, password: TEST_PASSWORD });
    expect(login.status).toBe(200);

    const despues = await request(app).get('/api/auth/me').set(auth(login.body.data.token));
    expect(despues.status).toBe(200);
  });

  it('test_exactamente_30_minutos_todavia_no_cierra_la_sesion', async () => {
    await ponerInactividad(30 * 60 - 5);

    expect((await yo()).status).toBe(200);
  });
});
