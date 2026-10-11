import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
const TOTAL = 1000;
const LIMITE_MS = 2000;
let token;
let usuarioId;
let mecanico;

/** Mide cuánto tarda una petición (SC-008: menos de 2 s con hasta 1 000 registros). */
async function medir(url) {
  const inicio = performance.now();
  const res = await request(app).get(url).set(auth(token));
  return { res, ms: performance.now() - inicio };
}

beforeAll(async () => {
  await resetDatabase();
  const usuario = await createUserWithToken('RECEPTIONIST');
  token = usuario.token;
  usuarioId = usuario.id;
  mecanico = await createUserWithToken('MECHANIC');

  const clientes = Array.from({ length: TOTAL }, (_, i) => [
    `Cliente número ${i}`,
    `55${String(10000000 + i)}`,
    `cliente${i}@carga.local`,
  ]);
  await query(
    `INSERT INTO clients (name, phone, email) VALUES ${clientes.map(() => '(?, ?, ?)').join(', ')}`,
    clientes.flat(),
  );
  const ids = (await query('SELECT id FROM clients ORDER BY id')).map((c) => c.id);
  const vehiculos = ids.map((id, i) => [id, i % 2 ? 'Nissan' : 'Toyota', `Modelo ${i}`, 2000 + (i % 25), `CAR-${String(i).padStart(4, '0')}-X`]);
  await query(
    `INSERT INTO vehicles (client_id, brand, model, year, license_plate) VALUES ${vehiculos.map(() => '(?, ?, ?, ?, ?)').join(', ')}`,
    vehiculos.flat(),
  );

  // Sprint 2: una cita y una orden por vehículo (SC-010). Las órdenes recorren los seis estados.
  const vehiculosConDueno = await query('SELECT id, client_id FROM vehicles ORDER BY id');
  const estados = ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO', 'ENTREGADO'];
  const estadosCita = ['PENDIENTE', 'CONFIRMADA', 'EN_PROCESO', 'COMPLETADA', 'CANCELADA'];
  const base = Date.now() + 24 * 3600 * 1000;
  const citas = vehiculosConDueno.map((v, i) => [
    v.client_id,
    v.id,
    new Date(Math.floor((base + i * 3600 * 1000) / 1000) * 1000),
    `Motivo de la cita ${i}`,
    estadosCita[i % estadosCita.length],
    usuarioId,
  ]);
  await query(
    `INSERT INTO appointments (client_id, vehicle_id, scheduled_at, reason, status, created_by) VALUES ${citas.map(() => '(?, ?, ?, ?, ?, ?)').join(', ')}`,
    citas.flat(),
  );
  const ordenes = vehiculosConDueno.map((v, i) => [
    v.client_id,
    v.id,
    i % 3 === 0 ? null : mecanico.id,
    estados[i % estados.length],
    `Problema reportado número ${i}`,
    1000 + i,
    usuarioId,
  ]);
  await query(
    `INSERT INTO service_orders (client_id, vehicle_id, mechanic_id, status, reported_problem, entry_mileage, created_by) VALUES ${ordenes.map(() => '(?, ?, ?, ?, ?, ?, ?)').join(', ')}`,
    ordenes.flat(),
  );
}, 60000);

describe(`rendimiento con ${TOTAL} clientes y ${TOTAL} vehículos (SC-008)`, () => {
  it('test_el_listado_de_clientes_responde_en_menos_de_2_segundos', async () => {
    const { res, ms } = await medir('/api/clients');

    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(TOTAL);
    expect(ms).toBeLessThan(LIMITE_MS);
  });

  it.each([
    ['nombre', '/api/clients?search=n%C3%BAmero%2099'],
    ['telefono', '/api/clients?search=551000099'],
  ])('test_la_busqueda_de_clientes_por_%s_responde_en_menos_de_2_segundos', async (_campo, url) => {
    const { res, ms } = await medir(url);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(ms).toBeLessThan(LIMITE_MS);
  });

  it('test_el_listado_de_vehiculos_responde_en_menos_de_2_segundos', async () => {
    const { res, ms } = await medir('/api/vehicles');

    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(TOTAL);
    expect(ms).toBeLessThan(LIMITE_MS);
  });

  it.each([
    ['placa', '/api/vehicles?search=CAR-05'],
    ['marca', '/api/vehicles?search=nissan'],
    ['propietario', '/api/vehicles?search=n%C3%BAmero%20500'],
  ])('test_la_busqueda_de_vehiculos_por_%s_responde_en_menos_de_2_segundos', async (_campo, url) => {
    const { res, ms } = await medir(url);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(ms).toBeLessThan(LIMITE_MS);
  });

  it('test_la_ultima_pagina_tambien_responde_en_menos_de_2_segundos', async () => {
    const { res, ms } = await medir('/api/clients?page=50&pageSize=20');

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(20);
    expect(ms).toBeLessThan(LIMITE_MS);
  });
});

describe(`rendimiento de citas y órdenes con ${TOTAL} registros (SC-010)`, () => {
  it('test_el_listado_de_citas_y_sus_filtros_responden_en_menos_de_2_segundos', async () => {
    const desde = encodeURIComponent(new Date(Date.now() + 100 * 3600 * 1000).toISOString());
    const hasta = encodeURIComponent(new Date(Date.now() + 200 * 3600 * 1000).toISOString());
    for (const url of [
      '/api/appointments',
      '/api/appointments?status=CONFIRMADA',
      '/api/appointments?search=n%C3%BAmero%20500',
      '/api/appointments?search=CAR-05',
      `/api/appointments?from=${desde}&to=${hasta}`,
      '/api/appointments?page=50&pageSize=20',
    ]) {
      const { res, ms } = await medir(url);

      expect(res.status).toBe(200);
      expect(ms).toBeLessThan(LIMITE_MS);
      if (url === '/api/appointments') expect(res.body.meta.total).toBe(TOTAL);
      if (!url.includes('page=50')) expect(res.body.data.length).toBeGreaterThan(0);
    }
  });

  it('test_el_listado_de_ordenes_y_sus_filtros_responden_en_menos_de_2_segundos', async () => {
    const [{ id }] = await query("SELECT id FROM service_orders WHERE reported_problem = 'Problema reportado número 250'");
    for (const url of [
      '/api/orders',
      '/api/orders?status=EN_REPARACION',
      `/api/orders?mechanicId=${mecanico.id}`,
      `/api/orders?search=OS-${id}`,
      `/api/orders?search=${id}`,
      '/api/orders?search=CAR-05',
      '/api/orders?search=n%C3%BAmero%20500',
      '/api/orders?page=50&pageSize=20',
    ]) {
      const { res, ms } = await medir(url);

      expect(res.status).toBe(200);
      expect(ms).toBeLessThan(LIMITE_MS);
      if (url === '/api/orders') expect(res.body.meta.total).toBe(TOTAL);
      if (!url.includes('page=50')) expect(res.body.data.length).toBeGreaterThan(0);
    }
  });

  it('test_el_mecanico_obtiene_sus_ordenes_en_menos_de_2_segundos', async () => {
    const inicio = performance.now();
    const res = await request(app).get('/api/orders').set(auth(mecanico.token));
    const ms = performance.now() - inicio;

    expect(res.status).toBe(200);
    expect(res.body.data.every((o) => o.mechanic.id === mecanico.id && o.status !== 'ENTREGADO')).toBe(true);
    expect(ms).toBeLessThan(LIMITE_MS);
  });

  it('test_el_detalle_de_una_orden_responde_en_menos_de_2_segundos', async () => {
    const [{ id }] = await query('SELECT id FROM service_orders ORDER BY id DESC LIMIT 1');

    const { res, ms } = await medir(`/api/orders/${id}`);

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
  });
});
