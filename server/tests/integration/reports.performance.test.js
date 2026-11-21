import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
const TOTAL = 1000;
const PERIODO = { from: '2026-01-01', to: '2026-12-31' };
let admin;

/** Inserta filas por tandas con una sola sentencia para no tardar en preparar los datos. */
async function insertar(sql, filas, columnas) {
  const lote = 200;
  for (let i = 0; i < filas.length; i += lote) {
    const parte = filas.slice(i, i + lote);
    const marcas = parte.map(() => `(${Array(columnas).fill('?').join(', ')})`).join(', ');
    await query(`${sql} VALUES ${marcas}`, parte.flat());
  }
}

beforeAll(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  const mecanico = await createUserWithToken('MECHANIC');
  const { client, vehicle } = await createClientWithVehicle({ licensePlate: 'PER-001-A' });
  const parte = await createPart(admin.id, { stock: 0, purchasePrice: '50.00', salePrice: '80.00' });

  // 1 000 órdenes entregadas del mismo vehículo (solo una orden abierta por vehículo), terminadas el 15 de junio.
  await insertar(
    'INSERT INTO service_orders (client_id, vehicle_id, mechanic_id, status, reported_problem, entry_mileage, created_by)',
    Array.from({ length: TOTAL }, () => [client.id, vehicle.id, mecanico.id, 'ENTREGADO', 'Prueba de rendimiento', 50000, admin.id]),
    7,
  );
  const ordenes = (await query('SELECT id FROM service_orders ORDER BY id')).map((o) => o.id);
  await insertar(
    'INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at)',
    ordenes.map((id) => [id, 'EN_REPARACION', 'TERMINADO', admin.id, '2026-06-15 10:00:00']),
    5,
  );
  await insertar('INSERT INTO order_services (order_id, description, amount)', ordenes.map((id, i) => [id, `Servicio ${i % 25}`, '500.00']), 3);
  await insertar('INSERT INTO order_labor (order_id, description, amount)', ordenes.map((id) => [id, 'Mano de obra', '120.00']), 3);
  await insertar(
    'INSERT INTO order_parts (order_id, part_id, quantity, unit_price, created_by, created_at)',
    ordenes.map((id) => [id, parte.id, 2, '80.00', mecanico.id, '2026-06-15 10:00:00']),
    6,
  );
  await insertar(
    'INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by, created_at)',
    ordenes.map((id) => [parte.id, 'OUT', -2, 'Uso en orden', id, mecanico.id, '2026-06-15 10:00:00']),
    7,
  );
  await insertar(
    'INSERT INTO payments (order_id, amount, method, status, paid_at, created_by)',
    ordenes.map((id) => [id, '780.00', 'EFECTIVO', 'PAGADO', '2026-06-15 11:00:00', admin.id]),
    6,
  );
}, 120000);

describe('rendimiento de los reportes con 1 000 pagos y 1 000 órdenes (SC-006)', () => {
  it.each(['income', 'services', 'productivity', 'parts', 'rotation'])('test_%s_responde_en_menos_de_3_segundos_con_el_total_real', async (nombre) => {
    const inicio = Date.now();
    const res = await request(app).get(`/api/reports/${nombre}`).query(PERIODO).set(auth(admin.token));
    const duracion = Date.now() - inicio;

    expect(res.status).toBe(200);
    expect(duracion).toBeLessThan(3000);
    if (nombre === 'income') expect(res.body.data).toMatchObject({ total: '780000.00', paymentsCount: TOTAL });
    if (nombre === 'productivity') expect(res.body.data.items[0]).toMatchObject({ ordersFinished: TOTAL, laborAmount: '120000.00' });
    if (nombre === 'parts') expect(res.body.data.items[0]).toMatchObject({ units: 2 * TOTAL, revenue: '160000.00', cost: '100000.00' });
    if (nombre === 'services') expect(res.body.data.items.reduce((t, i) => t + i.times, 0)).toBe(TOTAL);
    if (nombre === 'rotation') expect(res.body.data.items[0].out).toBe(2 * TOTAL);
  });

  it('test_la_exportacion_a_excel_con_muchos_datos_tambien_responde_en_menos_de_3_segundos', async () => {
    const inicio = Date.now();
    const res = await request(app).get('/api/reports/parts').query({ ...PERIODO, format: 'xlsx' }).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Date.now() - inicio).toBeLessThan(3000);
  });
});
