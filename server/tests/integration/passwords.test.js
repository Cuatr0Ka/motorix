import request from 'supertest';
import bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { readStandardPasswords, runSeedFile } from '../helpers/seed.js';

const app = createApp();
const SENSIBLE = /passwordHash|password_hash|\$2[aby]\$/;

beforeEach(async () => {
  await resetDatabase();
  await runSeedFile();
  await runSeedFile('002_appointments_orders.sql');
});

describe('contraseñas de las cuentas iniciales (SC-005, CA-1, CA-10)', () => {
  it('test_las_cuatro_cuentas_guardan_solo_un_hash_bcrypt_de_costo_10', async () => {
    const usuarios = await query('SELECT username, password_hash FROM users ORDER BY username');

    expect(usuarios).toHaveLength(4);
    for (const { password_hash: hash } of usuarios) {
      expect(hash).toMatch(/^\$2[aby]\$10\$[./A-Za-z0-9]{53}$/);
    }
  });

  it('test_ninguna_contrasena_del_estandar_aparece_en_texto_plano_en_la_base', async () => {
    const estandar = Object.values(readStandardPasswords());
    expect(estandar).toHaveLength(4);

    const filas = await query('SELECT username, name, email, password_hash FROM users');
    const texto = JSON.stringify(filas);
    for (const contrasena of estandar) expect(texto).not.toContain(contrasena);
  });

  it('test_los_hashes_sembrados_corresponden_a_las_contrasenas_documentadas', async () => {
    const estandar = readStandardPasswords();

    for (const [usuario, contrasena] of Object.entries(estandar)) {
      const [fila] = await query('SELECT password_hash FROM users WHERE username = ?', [usuario]);
      expect(await bcrypt.compare(contrasena, fila.password_hash)).toBe(true);
    }
  });

  it.each([
    ['admin', 'ADMIN'],
    ['recepcion', 'RECEPTIONIST'],
    ['mecanico', 'MECHANIC'],
    ['mecanico2', 'MECHANIC'],
  ])('test_la_cuenta_%s_inicia_sesion_con_usuario_y_con_correo_y_devuelve_un_token', async (usuario, rol) => {
    const contrasena = readStandardPasswords()[usuario];

    const porUsuario = await request(app).post('/api/auth/login').send({ identifier: usuario, password: contrasena });
    const porCorreo = await request(app)
      .post('/api/auth/login')
      .send({ identifier: `${usuario}@motorix.local`, password: contrasena });

    expect(porUsuario.status).toBe(200);
    expect(porCorreo.status).toBe(200);
    expect(porUsuario.body.data.user.role).toBe(rol);
    expect(porUsuario.body.data.token.split('.')).toHaveLength(3);
  });
});

describe('ninguna respuesta de la API expone hashes ni contraseñas', () => {
  it('test_las_respuestas_de_login_perfil_usuarios_clientes_y_vehiculos_no_contienen_datos_sensibles', async () => {
    const contrasena = readStandardPasswords().admin;
    const login = await request(app).post('/api/auth/login').send({ identifier: 'admin', password: contrasena });
    const token = login.body.data.token;

    const respuestas = [
      login,
      await request(app).get('/api/auth/me').set(auth(token)),
      await request(app).get('/api/users').set(auth(token)),
      await request(app).get('/api/users/1').set(auth(token)),
      await request(app).get('/api/clients').set(auth(token)),
      await request(app).get('/api/vehicles').set(auth(token)),
    ];

    for (const res of respuestas) {
      expect(JSON.stringify(res.body)).not.toMatch(SENSIBLE);
      expect(JSON.stringify(res.body)).not.toContain(contrasena);
    }
  });

  it('test_los_errores_tampoco_devuelven_la_contrasena_enviada', async () => {
    const res = await request(app).post('/api/auth/login').send({ identifier: 'admin', password: 'Secreta2026x' });

    expect(res.status).toBe(401);
    expect(JSON.stringify(res.body)).not.toContain('Secreta2026x');
  });

  it('test_un_usuario_creado_por_la_api_se_guarda_con_hash_y_no_se_devuelve', async () => {
    const admin = await createUserWithToken('ADMIN');
    const res = await request(app)
      .post('/api/users')
      .set(auth(admin.token))
      .send({ username: 'nuevo', name: 'Nuevo', email: 'nuevo@prueba.local', role: 'MECHANIC', password: 'Clave2026x' });

    expect(res.status).toBe(201);
    expect(JSON.stringify(res.body)).not.toMatch(SENSIBLE);
    const [fila] = await query("SELECT password_hash FROM users WHERE username = 'nuevo'");
    expect(fila.password_hash).not.toContain('Clave2026x');
  });
});
