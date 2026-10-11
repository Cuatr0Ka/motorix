import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createUser, createUserWithToken, resetDatabase, TEST_PASSWORD } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const cuerpoNuevo = (extra = {}) => ({
  username: 'nuevo.usuario',
  name: 'Nuevo Usuario',
  email: 'nuevo@prueba.local',
  role: 'MECHANIC',
  password: 'Clave2026x',
  ...extra,
});

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('GET /api/users (contrato)', () => {
  it('test_lista_usuarios_sin_exponer_datos_sensibles', async () => {
    const res = await request(app).get('/api/users').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 3 });
    expect(res.body.data[0]).toEqual({
      id: expect.any(Number),
      username: expect.any(String),
      name: expect.any(String),
      email: expect.any(String),
      role: expect.any(String),
      active: true,
      createdAt: expect.any(String),
    });
    expect(JSON.stringify(res.body)).not.toMatch(/password|hash/i);
  });

  it('test_filtra_por_rol_estado_y_busqueda', async () => {
    await createUser({ username: 'baja.mecanico', role: 'MECHANIC', active: 0 });

    const mecanicos = await request(app).get('/api/users?role=MECHANIC').set(auth(admin.token));
    const inactivos = await request(app).get('/api/users?active=false').set(auth(admin.token));
    const busqueda = await request(app).get('/api/users?search=baja').set(auth(admin.token));

    expect(mecanicos.body.meta.total).toBe(2);
    expect(inactivos.body.data.map((u) => u.username)).toEqual(['baja.mecanico']);
    expect(busqueda.body.data).toHaveLength(1);
  });

  it('test_responde_400_con_un_rol_invalido', async () => {
    const res = await request(app).get('/api/users?role=DUENO').set(auth(admin.token));

    expect(res.status).toBe(400);
  });

  it.each([
    ['recepcionista', () => recepcion],
    ['mecanico', () => mecanico],
  ])('test_responde_403_para_el_%s', async (_nombre, quien) => {
    const res = await request(app).get('/api/users').set(auth(quien().token));

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_responde_401_sin_token', async () => {
    expect((await request(app).get('/api/users')).status).toBe(401);
  });
});

describe('POST /api/users (contrato)', () => {
  it('test_crea_un_usuario_y_devuelve_201_sin_la_contrasena', async () => {
    const res = await request(app).post('/api/users').set(auth(admin.token)).send(cuerpoNuevo());

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      username: 'nuevo.usuario',
      name: 'Nuevo Usuario',
      email: 'nuevo@prueba.local',
      role: 'MECHANIC',
      active: true,
    });
    expect(JSON.stringify(res.body)).not.toMatch(/password|hash|Clave2026x/i);
  });

  it('test_el_usuario_creado_puede_iniciar_sesion_con_su_contrasena', async () => {
    await request(app).post('/api/users').set(auth(admin.token)).send(cuerpoNuevo());

    const login = await request(app)
      .post('/api/auth/login')
      .send({ identifier: 'nuevo@prueba.local', password: 'Clave2026x' });

    expect(login.status).toBe(200);
    expect(login.body.data.user.role).toBe('MECHANIC');
  });

  it('test_responde_400_con_detalles_por_campo_si_faltan_datos', async () => {
    const res = await request(app).post('/api/users').set(auth(admin.token)).send({});

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual([
      'email',
      'name',
      'password',
      'role',
      'username',
    ]);
  });

  it('test_responde_403_para_quien_no_es_administrador', async () => {
    const res = await request(app).post('/api/users').set(auth(recepcion.token)).send(cuerpoNuevo());

    expect(res.status).toBe(403);
  });
});

describe('GET /api/users/:id y PATCH /api/users/:id (contrato)', () => {
  it('test_devuelve_un_usuario_por_id', async () => {
    const res = await request(app).get(`/api/users/${mecanico.id}`).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(mecanico.id);
  });

  it('test_responde_404_si_el_usuario_no_existe', async () => {
    const res = await request(app).get('/api/users/999999').set(auth(admin.token));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_actualiza_nombre_correo_rol_y_estado', async () => {
    const res = await request(app)
      .patch(`/api/users/${mecanico.id}`)
      .set(auth(admin.token))
      .send({ name: 'Otro Nombre', email: 'OTRO@prueba.local', role: 'RECEPTIONIST', active: false });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      name: 'Otro Nombre',
      email: 'otro@prueba.local',
      role: 'RECEPTIONIST',
      active: false,
    });
  });

  it('test_responde_400_si_el_cuerpo_viene_vacio', async () => {
    const res = await request(app).patch(`/api/users/${mecanico.id}`).set(auth(admin.token)).send({});

    expect(res.status).toBe(400);
  });

  it('test_no_permite_cambiar_el_nombre_de_usuario_ni_la_contrasena_por_esta_ruta', async () => {
    const res = await request(app)
      .patch(`/api/users/${mecanico.id}`)
      .set(auth(admin.token))
      .send({ name: 'Nombre', username: 'otro', password: 'Hack2026x' });

    expect(res.status).toBe(200);
    expect(res.body.data.username).toBe(mecanico.username);
    const login = await request(app)
      .post('/api/auth/login')
      .send({ identifier: mecanico.username, password: TEST_PASSWORD });
    expect(login.status).toBe(200);
  });

  it('test_responde_403_para_quien_no_es_administrador', async () => {
    const res = await request(app).patch(`/api/users/${mecanico.id}`).set(auth(recepcion.token)).send({ name: 'X' });

    expect(res.status).toBe(403);
  });
});

describe('POST /api/auth/change-password (contrato)', () => {
  const cambiar = (token, body) => request(app).post('/api/auth/change-password').set(auth(token)).send(body);

  it('test_cambia_la_contrasena_propia_y_permite_iniciar_sesion_con_la_nueva', async () => {
    const res = await cambiar(mecanico.token, { currentPassword: TEST_PASSWORD, newPassword: 'NuevaClave2026' });

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ changed: true });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ identifier: mecanico.username, password: 'NuevaClave2026' });
    expect(login.status).toBe(200);
  });

  it('test_responde_400_si_faltan_campos', async () => {
    const res = await cambiar(mecanico.token, {});

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['currentPassword', 'newPassword']);
  });

  it('test_responde_401_sin_token', async () => {
    const res = await request(app)
      .post('/api/auth/change-password')
      .send({ currentPassword: TEST_PASSWORD, newPassword: 'NuevaClave2026' });

    expect(res.status).toBe(401);
  });
});
