import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const app = createApp();
const contar = async (tabla) => Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total);
const sembrar = async () => {
  await runSeedFile('001_initial_data.sql');
  await runSeedFile('002_appointments_orders.sql');
  await runSeedFile('003_history_inventory.sql');
};
const TABLAS = [
  'users',
  'vehicles',
  'service_orders',
  'order_services',
  'order_labor',
  'order_status_history',
  'parts',
  'inventory_movements',
  'order_parts',
  'maintenance',
];
const conteos = async () => Object.fromEntries(await Promise.all(TABLAS.map(async (t) => [t, await contar(t)])));
const existencias = async () => query('SELECT code, stock, min_stock, active FROM parts ORDER BY code');

beforeEach(resetDatabase);

describe('seed del Sprint 3 (FR-024, SC-011)', () => {
  it('test_crea_refacciones_en_los_tres_estados_de_stock_y_una_inactiva', async () => {
    await sembrar();

    const partes = await existencias();
    const estado = (p) => (p.stock === 0 ? 'AGOTADO' : p.stock <= p.min_stock ? 'BAJO' : 'SUFICIENTE');
    const activas = partes.filter((p) => p.active);

    expect(partes.length).toBeGreaterThanOrEqual(12);
    expect(new Set(activas.map(estado))).toEqual(new Set(['SUFICIENTE', 'BAJO', 'AGOTADO']));
    expect(partes.filter((p) => !p.active)).toHaveLength(1);
    expect(Object.fromEntries(partes.map((p) => [p.code, p.stock]))).toMatchObject({
      'ACE-5W30': 54,
      'BAL-TRA': 2,
      'BUJ-NGK': 6,
      'COR-DIS': 0,
      'BOM-AGU': 0,
    });
  });

  it('test_crea_movimientos_de_entrada_salida_y_ajuste', async () => {
    await sembrar();

    const tipos = (await query('SELECT DISTINCT type FROM inventory_movements')).map((m) => m.type).sort();
    expect(tipos).toEqual(['ADJUSTMENT', 'IN', 'OUT']);
    const ajustes = await query("SELECT reason, quantity FROM inventory_movements WHERE type = 'ADJUSTMENT'");
    expect(ajustes.length).toBeGreaterThanOrEqual(2);
    for (const ajuste of ajustes) expect(ajuste.reason.length).toBeGreaterThanOrEqual(5);
  });

  it('test_el_stock_de_cada_refaccion_es_la_suma_de_sus_movimientos_y_nunca_es_negativo', async () => {
    await sembrar();

    const filas = await query(
      `SELECT p.code, p.stock, COALESCE(SUM(m.quantity), 0) AS suma
         FROM parts p LEFT JOIN inventory_movements m ON m.part_id = p.id GROUP BY p.id, p.code, p.stock`,
    );
    for (const fila of filas) {
      expect([fila.code, Number(fila.suma)]).toEqual([fila.code, fila.stock]);
      expect(fila.stock).toBeGreaterThanOrEqual(0);
    }
  });

  it('test_cada_refaccion_usada_en_una_orden_tiene_su_salida_ligada_a_la_orden', async () => {
    await sembrar();

    const lineas = await query('SELECT order_id, part_id, quantity FROM order_parts');
    expect(lineas.length).toBeGreaterThanOrEqual(15);
    for (const linea of lineas) {
      const [{ total }] = await query(
        "SELECT COALESCE(SUM(-quantity), 0) AS total FROM inventory_movements WHERE type = 'OUT' AND order_id = ? AND part_id = ?",
        [linea.order_id, linea.part_id],
      );
      expect(Number(total)).toBe(linea.quantity);
    }
    const [motivo] = await query("SELECT reason FROM inventory_movements WHERE type = 'OUT' LIMIT 1");
    expect(motivo.reason).toMatch(/^Uso en OS-\d{6}$/);
  });

  it('test_forma_historial_en_varios_vehiculos_con_kilometraje_de_servicio', async () => {
    await sembrar();

    const [{ vehiculos }] = await query(
      "SELECT COUNT(DISTINCT vehicle_id) AS vehiculos FROM service_orders WHERE status IN ('TERMINADO', 'ENTREGADO')",
    );
    expect(Number(vehiculos)).toBeGreaterThanOrEqual(8);
    const sinKm = await query("SELECT id FROM service_orders WHERE status IN ('TERMINADO', 'ENTREGADO') AND service_mileage IS NULL");
    expect(sinKm).toEqual([]);
    const incoherentes = await query('SELECT id FROM service_orders WHERE service_mileage IS NOT NULL AND service_mileage < entry_mileage');
    expect(incoherentes).toEqual([]);

    const admin = await createUserWithToken('ADMIN');
    const [vehiculo] = await query("SELECT id FROM vehicles WHERE license_plate = 'ABC-123-A'");
    const res = await request(app).get(`/api/vehicles/${vehiculo.id}/history`).set(auth(admin.token));
    expect(res.status).toBe(200);
    expect(res.body.data.entries.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data.entries[0].parts.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data.entries[0].services.length).toBeGreaterThanOrEqual(1);
  });

  it('test_crea_mantenimientos_normal_proximo_vencido_y_atendido', async () => {
    await sembrar();
    const admin = await createUserWithToken('ADMIN');

    const pendientes = await request(app).get('/api/maintenance?pageSize=100').set(auth(admin.token));
    const indicadores = new Set(pendientes.body.data.map((m) => m.indicator));
    const atendidos = await request(app).get('/api/maintenance?status=ATENDIDO&pageSize=100').set(auth(admin.token));

    expect(pendientes.status).toBe(200);
    expect(indicadores).toEqual(new Set(['NORMAL', 'PROXIMO', 'VENCIDO']));
    expect(pendientes.body.data[0].indicator).toBe('VENCIDO');
    expect(atendidos.body.data.length).toBeGreaterThanOrEqual(2);
    const porVehiculo = await query("SELECT vehicle_id, COUNT(*) AS total FROM maintenance WHERE status = 'PENDIENTE' GROUP BY vehicle_id");
    for (const fila of porVehiculo) expect(Number(fila.total)).toBe(1);
  });

  it('test_las_alertas_de_stock_muestran_bajas_y_agotadas_desde_el_primer_arranque', async () => {
    await sembrar();
    const admin = await createUserWithToken('ADMIN');

    const res = await request(app).get('/api/parts/alerts').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ count: 5, outOfStock: 2 });
    expect(res.body.data.items.slice(0, 2).map((p) => p.code).sort()).toEqual(['BOM-AGU', 'COR-DIS']);
    expect(res.body.data.items.map((p) => p.code)).not.toContain('DIS-OLD');
  });

  it('test_repetir_el_seed_tres_veces_no_duplica_ni_cambia_nada', async () => {
    await sembrar();
    const primero = await conteos();
    const stock = await existencias();

    await sembrar();
    await sembrar();

    expect(await conteos()).toEqual(primero);
    expect(await existencias()).toEqual(stock);
    for (const [tabla, total] of Object.entries(primero)) expect([tabla, total]).toEqual([tabla, await contar(tabla)]);
  });

  it('test_repetir_el_seed_conserva_los_cambios_hechos_despues_de_instalar', async () => {
    await sembrar();
    const admin = await createUserWithToken('ADMIN');
    const [parte] = await query("SELECT id FROM parts WHERE code = 'COR-DIS'");
    await request(app).post(`/api/parts/${parte.id}/movements`).set(auth(admin.token)).send({ type: 'IN', quantity: 7, reason: 'Compra de prueba' });
    await query("UPDATE parts SET name = 'Correa personalizada', min_stock = 9 WHERE code = 'COR-DIS'");

    await sembrar();

    const [fila] = await query("SELECT name, min_stock, stock FROM parts WHERE code = 'COR-DIS'");
    expect(fila).toEqual({ name: 'Correa personalizada', min_stock: 9, stock: 7 });
  });
});
