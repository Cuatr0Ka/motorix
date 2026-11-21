import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  TEST_PASSWORD,
  auth,
  createClientWithVehicle,
  createPart,
  createPayableOrder,
  createPayment,
  createServiceType,
  createUser,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const filas = (accion) => query('SELECT * FROM audit_log WHERE action = ? ORDER BY id', [accion]);
const login = (identifier, password) => request(app).post('/api/auth/login').send({ identifier, password });

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('bitácora de acciones sensibles (US10, FR-014 y FR-015)', () => {
  it('test_un_inicio_fallido_de_una_cuenta_existente_queda_atribuido_y_sin_el_texto_tecleado', async () => {
    await login(recepcion.username, 'ContraseñaEquivocada9');

    const [fila] = await filas('LOGIN_FAILED');
    expect(fila.actor_user_id).toBe(recepcion.id);
    expect(JSON.stringify(fila)).not.toContain('ContraseñaEquivocada9');
  });

  it('test_un_intento_con_una_cuenta_inexistente_no_deja_registro', async () => {
    await login('nadie.existe', 'Cualquiera12345');

    expect(await filas('LOGIN_FAILED')).toHaveLength(0);
  });

  it('test_cinco_fallos_bloquean_la_cuenta_y_quedan_registrados', async () => {
    for (let i = 0; i < 5; i += 1) await login(recepcion.username, 'Equivocada12345');

    expect(await filas('LOGIN_FAILED')).toHaveLength(5);
    const bloqueos = await filas('ACCOUNT_LOCKED');
    expect(bloqueos).toHaveLength(1);
    expect(bloqueos[0].actor_user_id).toBe(recepcion.id);
  });

  it('test_el_cambio_de_contrasena_propio_queda_registrado', async () => {
    await request(app)
      .post('/api/auth/change-password')
      .set(auth(recepcion.token))
      .send({ currentPassword: TEST_PASSWORD, newPassword: 'NuevaClave2026' });

    const [fila] = await filas('PASSWORD_CHANGED');
    expect(fila.actor_user_id).toBe(recepcion.id);
    expect(JSON.stringify(fila)).not.toContain('NuevaClave2026');
  });

  it('test_alta_desactivacion_activacion_y_cambio_de_rol_de_usuarios', async () => {
    const alta = await request(app)
      .post('/api/users')
      .set(auth(admin.token))
      .send({ username: 'nuevo.mec', name: 'Nuevo Mecánico', email: 'nuevo.mec@prueba.local', role: 'MECHANIC', password: 'ClaveSegura2026' });
    const id = alta.body.data.id;
    await request(app).patch(`/api/users/${id}`).set(auth(admin.token)).send({ role: 'RECEPTIONIST' });
    await request(app).patch(`/api/users/${id}`).set(auth(admin.token)).send({ active: false });
    await request(app).patch(`/api/users/${id}`).set(auth(admin.token)).send({ active: true });

    expect(await filas('USER_CREATED')).toHaveLength(1);
    const [rol] = await filas('USER_ROLE_CHANGED');
    expect(rol.summary).toContain('MECHANIC → RECEPTIONIST');
    expect(await filas('USER_DEACTIVATED')).toHaveLength(1);
    expect(await filas('USER_ACTIVATED')).toHaveLength(1);
    expect((await filas('USER_CREATED'))[0].actor_user_id).toBe(admin.id);
    expect(JSON.stringify(await query('SELECT * FROM audit_log'))).not.toContain('ClaveSegura2026');
  });

  it('test_settings_y_service_type_changed_quedan_registrados', async () => {
    await request(app).put('/api/settings').set(auth(admin.token)).send({ shop: { name: 'Taller Nuevo' } });
    await request(app).post('/api/service-types').set(auth(admin.token)).send({ name: 'Afinación', intervalDays: 365 });

    expect(await filas('SETTINGS_CHANGED')).toHaveLength(1);
    expect(await filas('SERVICE_TYPE_CHANGED')).toHaveLength(1);
  });

  it('test_el_precio_de_una_refaccion_se_registra_solo_si_cambia_el_de_compra_o_el_de_venta', async () => {
    const parte = await createPart(admin.id, { name: 'Balatas delanteras', salePrice: '780.00', purchasePrice: '500.00' });

    await request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ name: 'Balatas delanteras nuevas' });
    expect(await filas('PART_PRICE_CHANGED')).toHaveLength(0);

    await request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ salePrice: '820.00' });
    const [fila] = await filas('PART_PRICE_CHANGED');
    expect(fila.summary).toContain('venta 780.00 → 820.00');
  });

  it('test_cancelar_un_pago_y_aceptar_los_terminos_quedan_registrados', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'AUD-001-A' });
    const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
    // Solo un pago pendiente se puede cancelar.
    const pago = await createPayment(orden.id, recepcion.id, { status: 'PENDIENTE', method: 'MERCADO_PAGO' });
    await request(app).post(`/api/payments/${pago.id}/cancel`).set(auth(recepcion.token));

    const [fila] = await filas('PAYMENT_CANCELLED');
    expect(fila.summary).toContain('OS-');

    const sinAceptar = await createUserWithToken('MECHANIC', { acceptTerms: false });
    const { id } = (await request(app).get('/api/terms/current').set(auth(sinAceptar.token))).body.data;
    await request(app).post('/api/terms/accept').set(auth(sinAceptar.token)).send({ versionId: id });
    expect(await filas('TERMS_ACCEPTED')).toHaveLength(1);
  });

  it('test_la_consulta_filtra_por_fecha_usuario_y_accion_pagina_y_ordena_de_nuevo_a_antiguo', async () => {
    for (let i = 0; i < 3; i += 1) await login(recepcion.username, 'Equivocada12345');
    await login(mecanico.username, 'Equivocada12345');

    const todo = await request(app).get('/api/audit-log?pageSize=2').set(auth(admin.token));
    expect(todo.status).toBe(200);
    expect(todo.body.meta).toMatchObject({ page: 1, pageSize: 2, total: 4 });
    expect(todo.body.data).toHaveLength(2);
    const ids = todo.body.data.map((f) => f.id);
    expect(ids).toEqual([...ids].sort((a, b) => b - a));

    const porUsuario = await request(app).get(`/api/audit-log?userId=${recepcion.id}`).set(auth(admin.token));
    expect(porUsuario.body.meta.total).toBe(3);
    const porAccion = await request(app).get('/api/audit-log?action=ACCOUNT_LOCKED').set(auth(admin.token));
    expect(porAccion.body.meta.total).toBe(0);
    const ahora = new Date();
    const hoy = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, '0')}-${String(ahora.getDate()).padStart(2, '0')}`;
    expect((await request(app).get(`/api/audit-log?from=${hoy}&to=${hoy}`).set(auth(admin.token))).body.meta.total).toBe(4);
    expect((await request(app).get('/api/audit-log?from=2000-01-01&to=2000-01-02').set(auth(admin.token))).body.meta.total).toBe(0);
  });

  it('test_la_bitacora_no_tiene_rutas_de_escritura', async () => {
    for (const metodo of ['post', 'put', 'patch', 'delete']) {
      const res = await request(app)[metodo]('/api/audit-log').set(auth(admin.token)).send({});
      expect({ metodo, estado: res.status }).toEqual({ metodo, estado: 404 });
    }
  });

  it('test_ninguna_fila_contiene_contrasenas_hashes_tokens_ni_numeros_de_tarjeta', async () => {
    await login(recepcion.username, 'Equivocada12345');
    await createUser({ role: 'MECHANIC' });
    await request(app).post('/api/auth/change-password').set(auth(mecanico.token)).send({ currentPassword: TEST_PASSWORD, newPassword: 'OtraClave2026x' });
    await createServiceType();
    await request(app).put('/api/settings').set(auth(admin.token)).send({ maintenance: { warnDays: 20 } });

    const texto = JSON.stringify(await query('SELECT * FROM audit_log'));
    expect(texto).not.toMatch(/\$2[aby]\$/);
    expect(texto).not.toMatch(/bearer|jwt|token/i);
    expect(texto).not.toMatch(/\b\d{13,19}\b/);
    expect(texto).not.toContain('Equivocada12345');
    expect(texto).not.toContain('OtraClave2026x');
  });

  it('test_recepcion_y_mecanico_reciben_403_y_sin_token_401', async () => {
    for (const u of [recepcion, mecanico]) expect((await request(app).get('/api/audit-log').set(auth(u.token))).status).toBe(403);
    expect((await request(app).get('/api/audit-log')).status).toBe(401);
  });
});

import { afterAll } from '@jest/globals';
afterAll(() => resetGateway());
