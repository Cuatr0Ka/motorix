import request from 'supertest';
import bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUser, createUserWithToken, resetDatabase, TEST_PASSWORD } from '../helpers/factories.js';

const app = createApp();
let admin;

const crear = (body, token = admin.token) => request(app).post('/api/users').set(auth(token)).send(body);
const editar = (id, body, token = admin.token) => request(app).patch(`/api/users/${id}`).set(auth(token)).send(body);
const cuerpo = (extra = {}) => ({
  username: 'nuevo',
  name: 'Nuevo',
  email: 'nuevo@prueba.local',
  role: 'MECHANIC',
  password: 'Clave2026x',
  ...extra,
});

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
});

describe('unicidad de usuario y correo', () => {
  it('test_rechaza_un_nombre_de_usuario_repetido_aunque_cambie_la_capitalizacion', async () => {
    await createUser({ username: 'Ana' });

    const res = await crear(cuerpo({ username: 'ANA', email: 'otra@prueba.local' }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('USERNAME_DUPLICATE');
  });

  it('test_rechaza_un_correo_repetido_aunque_cambie_la_capitalizacion', async () => {
    await createUser({ email: 'ana@prueba.local' });

    const res = await crear(cuerpo({ email: 'ANA@Prueba.local' }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_DUPLICATE');
  });

  it('test_rechaza_cambiar_el_correo_al_de_otro_usuario', async () => {
    await createUser({ email: 'ocupado@prueba.local' });
    const otro = await createUser();

    const res = await editar(otro.id, { email: 'ocupado@prueba.local' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_DUPLICATE');
  });

  it('test_permite_conservar_el_propio_correo_al_editar', async () => {
    const otro = await createUser({ email: 'propio@prueba.local' });

    const res = await editar(otro.id, { email: 'PROPIO@prueba.local', name: 'Nombre nuevo' });

    expect(res.status).toBe(200);
  });
});

describe('validación del alta', () => {
  it.each([
    ['usuario de 2 caracteres', { username: 'ab' }, 'username'],
    ['usuario de mas de 50 caracteres', { username: 'u'.repeat(51) }, 'username'],
    ['usuario con arroba', { username: 'ana@taller' }, 'username'],
    ['usuario con espacios', { username: 'ana lopez' }, 'username'],
    ['nombre de mas de 120 caracteres', { name: 'N'.repeat(121) }, 'name'],
    ['correo invalido', { email: 'sin-arroba' }, 'email'],
    ['rol inexistente', { role: 'DUENO' }, 'role'],
  ])('test_rechaza_%s', async (_nombre, extra, campo) => {
    const res = await crear(cuerpo(extra));

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });

  it.each([
    ['menos de 8 caracteres', 'Ab1cdef'],
    ['sin mayuscula', 'clave2026x'],
    ['sin minuscula', 'CLAVE2026X'],
    ['sin numero', 'ClaveSinNumero'],
  ])('test_rechaza_una_contrasena_con_%s', async (_nombre, password) => {
    const res = await crear(cuerpo({ password }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PASSWORD_POLICY');
  });

  it('test_guarda_la_contrasena_solo_como_hash_bcrypt', async () => {
    await crear(cuerpo());

    const [fila] = await query('SELECT password_hash FROM users WHERE username = ?', ['nuevo']);
    expect(fila.password_hash).not.toContain('Clave2026x');
    expect(fila.password_hash).toMatch(/^\$2[aby]\$10\$/);
    expect(await bcrypt.compare('Clave2026x', fila.password_hash)).toBe(true);
  });
});

describe('último administrador activo (FR-017)', () => {
  it('test_rechaza_desactivar_al_unico_administrador_activo', async () => {
    const res = await editar(admin.id, { active: false });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('LAST_ADMIN');
    const [fila] = await query('SELECT active FROM users WHERE id = ?', [admin.id]);
    expect(fila.active).toBe(1);
  });

  it('test_rechaza_cambiar_de_rol_al_unico_administrador_activo', async () => {
    const res = await editar(admin.id, { role: 'RECEPTIONIST' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('LAST_ADMIN');
  });

  it('test_permite_el_cambio_si_existe_otro_administrador_activo', async () => {
    await createUser({ role: 'ADMIN' });

    expect((await editar(admin.id, { role: 'RECEPTIONIST' })).status).toBe(200);
  });

  it('test_un_administrador_inactivo_no_cuenta_como_respaldo', async () => {
    await createUser({ role: 'ADMIN', active: 0 });

    const res = await editar(admin.id, { active: false });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('LAST_ADMIN');
  });

  it('test_dos_administradores_no_pueden_desactivarse_a_la_vez', async () => {
    const segundo = await createUserWithToken('ADMIN');

    const resultados = await Promise.all([
      editar(admin.id, { active: false }, segundo.token),
      editar(segundo.id, { active: false }, admin.token),
    ]);

    const [{ activos }] = await query("SELECT COUNT(*) AS activos FROM users WHERE role = 'ADMIN' AND active = 1");
    expect(activos).toBeGreaterThanOrEqual(1);
    expect(resultados.map((r) => r.status).filter((s) => s === 200).length).toBeLessThanOrEqual(2);
  });

  it('test_reactivar_o_editar_otros_campos_no_dispara_la_regla', async () => {
    expect((await editar(admin.id, { name: 'Admin renombrado' })).status).toBe(200);
  });
});

describe('efecto inmediato sobre una sesión abierta', () => {
  it('test_desactivar_a_un_usuario_rechaza_su_siguiente_peticion_aunque_su_token_siga_vigente', async () => {
    const mecanico = await createUserWithToken('MECHANIC');
    expect((await request(app).get('/api/clients').set(auth(mecanico.token))).status).toBe(200);

    await editar(mecanico.id, { active: false });

    const res = await request(app).get('/api/clients').set(auth(mecanico.token));
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('test_cambiar_el_rol_aplica_los_permisos_nuevos_en_la_siguiente_peticion', async () => {
    const mecanico = await createUserWithToken('MECHANIC');
    const alta = { name: 'Cliente', phone: '5512345678' };
    expect((await request(app).post('/api/clients').set(auth(mecanico.token)).send(alta)).status).toBe(403);

    await editar(mecanico.id, { role: 'RECEPTIONIST' });

    expect((await request(app).post('/api/clients').set(auth(mecanico.token)).send(alta)).status).toBe(201);
  });

  it('test_degradar_a_un_administrador_le_quita_el_acceso_a_usuarios_de_inmediato', async () => {
    const segundo = await createUserWithToken('ADMIN');
    expect((await request(app).get('/api/users').set(auth(segundo.token))).status).toBe(200);

    await editar(segundo.id, { role: 'MECHANIC' });

    expect((await request(app).get('/api/users').set(auth(segundo.token))).status).toBe(403);
  });
});

describe('cambio de contraseña', () => {
  const cambiar = (token, body) => request(app).post('/api/auth/change-password').set(auth(token)).send(body);
  let usuario;

  beforeEach(async () => {
    usuario = await createUserWithToken('RECEPTIONIST');
  });

  it('test_rechaza_con_401_si_la_contrasena_actual_es_incorrecta', async () => {
    const res = await cambiar(usuario.token, { currentPassword: 'Incorrecta1', newPassword: 'NuevaClave2026' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('test_rechaza_con_422_si_la_nueva_es_igual_a_la_actual', async () => {
    const res = await cambiar(usuario.token, { currentPassword: TEST_PASSWORD, newPassword: TEST_PASSWORD });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SAME_PASSWORD');
  });

  it.each([
    ['corta', 'Ab1cdef'],
    ['sin mayuscula', 'nuevaclave2026'],
    ['sin minuscula', 'NUEVACLAVE2026'],
    ['sin numero', 'NuevaClaveSola'],
  ])('test_rechaza_con_422_una_contrasena_nueva_%s', async (_nombre, newPassword) => {
    const res = await cambiar(usuario.token, { currentPassword: TEST_PASSWORD, newPassword });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PASSWORD_POLICY');
  });

  it('test_tras_el_cambio_la_contrasena_anterior_deja_de_funcionar', async () => {
    await cambiar(usuario.token, { currentPassword: TEST_PASSWORD, newPassword: 'NuevaClave2026' });

    const vieja = await request(app).post('/api/auth/login').send({ identifier: usuario.username, password: TEST_PASSWORD });
    const nueva = await request(app).post('/api/auth/login').send({ identifier: usuario.username, password: 'NuevaClave2026' });

    expect(vieja.status).toBe(401);
    expect(nueva.status).toBe(200);
  });

  it('test_una_contrasena_actual_incorrecta_no_modifica_nada', async () => {
    await cambiar(usuario.token, { currentPassword: 'Incorrecta1', newPassword: 'NuevaClave2026' });

    const login = await request(app).post('/api/auth/login').send({ identifier: usuario.username, password: TEST_PASSWORD });
    expect(login.status).toBe(200);
  });
});
