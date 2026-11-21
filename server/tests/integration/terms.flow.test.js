import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let nuevo; // usuario que todavía no acepta

const actual = (u) => request(app).get('/api/terms/current').set(auth(u.token));
const aceptar = (u, versionId) => request(app).post('/api/terms/accept').set(auth(u.token)).send({ versionId });

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  nuevo = await createUserWithToken('RECEPTIONIST', { acceptTerms: false });
});

describe('términos y condiciones (US9, FR-010 a FR-012)', () => {
  it('test_current_devuelve_la_version_1_0_sin_aceptar_y_luego_aceptada', async () => {
    const antes = await actual(nuevo);
    expect(antes.status).toBe(200);
    expect(antes.body.data).toMatchObject({ version: '1.0', accepted: false });

    expect((await aceptar(nuevo, antes.body.data.id)).status).toBe(200);

    expect((await actual(nuevo)).body.data.accepted).toBe(true);
  });

  it('test_el_texto_1_0_cubre_uso_confidencialidad_cuentas_y_privacidad', async () => {
    const texto = (await actual(admin)).body.data.body.toLowerCase();

    for (const palabra of ['uso permitido', 'confidencial', 'cuenta', 'privacidad']) expect(texto).toContain(palabra);
  });

  it('test_aceptar_guarda_usuario_version_y_fecha_y_es_idempotente', async () => {
    const { id } = (await actual(nuevo)).body.data;
    const primera = await aceptar(nuevo, id);
    const segunda = await aceptar(nuevo, id);

    expect(primera.body.data).toMatchObject({ versionId: id, version: '1.0' });
    expect(segunda.status).toBe(200);
    expect(segunda.body.data.acceptedAt).toBe(primera.body.data.acceptedAt);
    const filas = await query('SELECT * FROM terms_acceptances WHERE user_id = ?', [nuevo.id]);
    expect(filas).toHaveLength(1);
    const bitacora = await query("SELECT * FROM audit_log WHERE action = 'TERMS_ACCEPTED'");
    expect(bitacora).toHaveLength(1);
  });

  it('test_cinco_solicitudes_simultaneas_dejan_una_sola_fila', async () => {
    const { id } = (await actual(nuevo)).body.data;
    const respuestas = await Promise.all([1, 2, 3, 4, 5].map(() => aceptar(nuevo, id)));

    expect(respuestas.every((r) => r.status === 200)).toBe(true);
    expect(await query('SELECT * FROM terms_acceptances WHERE user_id = ?', [nuevo.id])).toHaveLength(1);
  });

  it('test_aceptar_una_version_que_ya_no_es_la_vigente_responde_409', async () => {
    const vieja = (await actual(nuevo)).body.data.id;
    await query("INSERT INTO terms_versions (version, title, body) VALUES ('2.0', 'Nuevos términos', 'Texto nuevo')");

    const res = await aceptar(nuevo, vieja);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('TERMS_VERSION_OUTDATED');
    expect(res.body.error.details.currentVersionId).toBeGreaterThan(vieja);
  });

  it('test_al_publicar_la_version_2_0_todos_quedan_sin_aceptar', async () => {
    await query("INSERT INTO terms_versions (version, title, body) VALUES ('2.0', 'Nuevos términos', 'Texto nuevo')");

    const res = await request(app).get('/api/clients').set(auth(admin.token));

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('TERMS_NOT_ACCEPTED');
    const actualAdmin = await actual(admin);
    expect(actualAdmin.body.data).toMatchObject({ version: '2.0', accepted: false });
    expect((await aceptar(admin, actualAdmin.body.data.id)).status).toBe(200);
    expect((await request(app).get('/api/clients').set(auth(admin.token))).status).toBe(200);
  });

  it('test_un_usuario_sin_aceptar_recibe_403_en_una_ruta_de_cada_router', async () => {
    const rutas = [
      '/api/clients',
      '/api/vehicles',
      '/api/appointments',
      '/api/orders',
      '/api/maintenance',
      '/api/parts',
      '/api/payments',
      '/api/tickets',
      '/api/dashboard',
      '/api/notifications',
      '/api/users',
      '/api/settings',
      '/api/service-types',
      '/api/client-notices',
    ];
    const { id, version } = (await actual(nuevo)).body.data;
    for (const ruta of rutas) {
      const res = await request(app).get(ruta).set(auth(nuevo.token));
      expect({ ruta, estado: res.status }).toEqual({ ruta, estado: 403 });
      expect(res.body.error.code).toBe('TERMS_NOT_ACCEPTED');
      expect(res.body.error.details).toEqual({ version, versionId: id });
    }
  });

  it('test_las_tres_rutas_permitidas_funcionan_sin_aceptar', async () => {
    expect((await actual(nuevo)).status).toBe(200);
    expect((await request(app).get('/api/auth/me').set(auth(nuevo.token))).status).toBe(200);
    expect((await aceptar(nuevo, (await actual(nuevo)).body.data.id)).status).toBe(200);
  });

  it('test_acceptances_es_solo_admin_pagina_y_cuenta_los_pendientes', async () => {
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const mecanico = await createUserWithToken('MECHANIC');

    const res = await request(app).get('/api/terms/acceptances?pageSize=2').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toMatchObject({ page: 1, pageSize: 2, total: 3, pending: 1, version: '1.0' });
    expect(res.body.data).toHaveLength(2);
    expect(Object.keys(res.body.data[0]).sort()).toEqual(['acceptedAt', 'name', 'userId', 'username']);
    for (const u of [recepcion, mecanico]) expect((await request(app).get('/api/terms/acceptances').set(auth(u.token))).status).toBe(403);
  });
});
