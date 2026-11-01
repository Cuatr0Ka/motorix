import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const app = createApp();
let recepcion;
let admin;

const ARCHIVOS_ANTERIORES = ['001_initial_data.sql', '002_appointments_orders.sql', '003_history_inventory.sql', '004_payments_tickets.sql'];
const SEED_5 = '005_part_prices.sql';
const PROBLEMA = 'Mantenimiento con refacciones (ejemplo Sprint 5)';

const sembrarAnteriores = async () => {
  for (const archivo of ARCHIVOS_ANTERIORES) await runSeedFile(archivo);
};
const sembrarTodo = async () => {
  await sembrarAnteriores();
  await runSeedFile(SEED_5);
};

const TABLAS = ['service_orders', 'order_services', 'order_labor', 'order_parts', 'order_status_history', 'inventory_movements', 'parts', 'payments', 'tickets'];
const conteos = async () =>
  Object.fromEntries(await Promise.all(TABLAS.map(async (tabla) => [tabla, Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total)])));

const detalle = (id, user = recepcion) => request(app).get(`/api/orders/${id}`).set(auth(user.token));
const idDeOrden = async (placa, problema) =>
  (await query('SELECT o.id FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id WHERE v.license_plate = ? AND o.reported_problem = ?', [placa, problema]))[0]?.id;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
});

describe('seed del Sprint 5 (FR-017, SC-011)', () => {
  it('test_es_idempotente_dos_ejecuciones_no_duplican_ningun_registro', async () => {
    await sembrarTodo();
    const primera = await conteos();

    await runSeedFile(SEED_5);
    await runSeedFile(SEED_5);

    expect(await conteos()).toEqual(primera);
  });

  it('test_asigna_categoria_marca_y_precios_y_deja_una_refaccion_sin_precio_de_venta', async () => {
    await sembrarTodo();

    const partes = await query('SELECT code, category, brand, purchase_price, sale_price FROM parts ORDER BY code');
    const sinPrecio = partes.filter((p) => p.sale_price === null).map((p) => p.code);
    const conPrecio = partes.filter((p) => p.sale_price !== null);

    expect(sinPrecio).toEqual(['BOM-AGU']);
    expect(conPrecio).toHaveLength(partes.length - 1);
    for (const parte of conPrecio) {
      expect(parte.category).toBeTruthy();
      expect(parte.brand).toBeTruthy();
      expect(Number(parte.purchase_price)).toBeGreaterThan(0);
      expect(Number(parte.sale_price)).toBeGreaterThan(Number(parte.purchase_price));
    }
  });

  it('test_no_sobrescribe_los_precios_que_el_administrador_ya_cambio', async () => {
    await sembrarTodo();
    await query("UPDATE parts SET sale_price = 12345.67, category = 'Ajustada a mano' WHERE code = 'BAL-DEL'");

    await runSeedFile(SEED_5);

    const [parte] = await query("SELECT sale_price, category FROM parts WHERE code = 'BAL-DEL'");
    expect(parte.sale_price).toBe('12345.67');
    expect(parte.category).toBe('Ajustada a mano');
  });

  it('test_crea_una_orden_terminada_cobrable_con_refacciones_con_precio_sin_pagos', async () => {
    await sembrarTodo();

    const id = await idDeOrden('VWX-234-H', PROBLEMA);
    const res = await detalle(id);

    expect(id).toBeDefined();
    expect(res.status).toBe(200);
    const orden = res.body.data;
    expect(orden.status).toBe('TERMINADO');
    expect(orden.mechanic).toBeTruthy();
    expect(orden.parts.length).toBeGreaterThanOrEqual(2);
    for (const linea of orden.parts) expect(Number(linea.unitPrice)).toBeGreaterThan(0);
    expect(orden.billing).toMatchObject({ canCharge: true, collectionStatus: 'SIN_COBRAR', amountOutdated: false, payments: [] });
    expect(Number(orden.billing.total)).toBe(Number(orden.totals.services) + Number(orden.totals.labor) + Number(orden.totals.parts));
    expect(Number(orden.totals.parts)).toBeGreaterThan(0);
    expect(orden.statusHistory.map((h) => h.toStatus)).toEqual(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO']);
  });

  it('test_la_orden_nueva_se_puede_cobrar_con_el_total_con_refacciones', async () => {
    await sembrarTodo();
    const id = await idDeOrden('VWX-234-H', PROBLEMA);
    const total = (await detalle(id)).body.data.billing.total;

    const res = await request(app).post(`/api/orders/${id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });

    expect(res.status).toBe(201);
    expect(res.body.data.amount).toBe(total);
  });

  it('test_la_orden_con_pago_de_mercado_pago_pendiente_queda_desfasada_y_conserva_las_lineas_anteriores', async () => {
    await sembrarTodo();
    const id = await idDeOrden('STU-901-G', 'Servicio de 40,000 km');

    const { billing, parts } = (await detalle(id)).body.data;

    expect(billing).toMatchObject({ collectionStatus: 'PENDIENTE', amountOutdated: true, canCharge: false });
    expect(Number(billing.total)).toBeGreaterThan(Number(billing.payments[0].amount));
    expect(billing.payments[0]).toMatchObject({ method: 'MERCADO_PAGO', status: 'PENDIENTE' });
    expect(parts.filter((p) => p.legacy).length).toBeGreaterThanOrEqual(2);
    expect(parts.filter((p) => !p.legacy)).toHaveLength(1);
  });

  it('test_no_modifica_pagos_tickets_lineas_anteriores_ni_ordenes_entregadas', async () => {
    await sembrarAnteriores();
    const pagosAntes = await query('SELECT id, order_id, amount, status, method FROM payments ORDER BY id');
    const ticketsAntes = await query('SELECT id, order_id, content FROM tickets ORDER BY id');
    const anterioresAntes = await query('SELECT id, order_id, part_id, quantity, unit_price FROM order_parts ORDER BY id');
    const entregadasAntes = await query("SELECT id, status, delivered_at FROM service_orders WHERE status = 'ENTREGADO' ORDER BY id");

    await runSeedFile(SEED_5);

    expect(await query('SELECT id, order_id, amount, status, method FROM payments ORDER BY id')).toEqual(pagosAntes);
    expect(await query('SELECT id, order_id, content FROM tickets ORDER BY id')).toEqual(ticketsAntes);
    expect(await query('SELECT id, order_id, part_id, quantity, unit_price FROM order_parts WHERE id <= ? ORDER BY id', [anterioresAntes.at(-1).id])).toEqual(anterioresAntes);
    expect(await query("SELECT id, status, delivered_at FROM service_orders WHERE status = 'ENTREGADO' ORDER BY id")).toEqual(entregadasAntes);
  });

  it('test_las_lineas_con_precio_solo_existen_en_ordenes_sin_pago_pagado_ni_entregadas', async () => {
    await sembrarTodo();

    const indebidas = await query(
      `SELECT op.id FROM order_parts op JOIN service_orders o ON o.id = op.order_id
        WHERE op.unit_price > 0
          AND (o.status = 'ENTREGADO' OR EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id AND p.status = 'PAGADO'))`,
    );

    expect(indebidas).toEqual([]);
  });

  it('test_el_stock_de_cada_refaccion_sigue_siendo_la_suma_de_sus_movimientos_y_nunca_es_negativo', async () => {
    await sembrarTodo();

    const filas = await query(
      `SELECT p.code, p.stock, COALESCE(SUM(m.quantity), 0) AS suma
         FROM parts p LEFT JOIN inventory_movements m ON m.part_id = p.id GROUP BY p.id, p.code, p.stock`,
    );

    for (const fila of filas) expect(Number(fila.suma)).toBe(fila.stock);
  });

  it('test_cada_linea_con_precio_tiene_su_salida_de_inventario_ligada_a_la_orden', async () => {
    await sembrarTodo();

    const sinSalida = await query(
      `SELECT op.id FROM order_parts op
        WHERE op.unit_price > 0
          AND NOT EXISTS (SELECT 1 FROM inventory_movements m WHERE m.order_id = op.order_id AND m.part_id = op.part_id AND m.type = 'OUT')`,
    );

    expect(sinSalida).toEqual([]);
  });

  it('test_las_ordenes_nuevas_cumplen_la_regla_de_una_sola_orden_abierta_por_vehiculo', async () => {
    await sembrarTodo();

    const repetidas = await query("SELECT vehicle_id FROM service_orders WHERE status <> 'ENTREGADO' GROUP BY vehicle_id HAVING COUNT(*) > 1");

    expect(repetidas).toEqual([]);
  });

  it('test_no_hay_credenciales_ni_datos_de_tarjeta_en_lo_sembrado', async () => {
    await sembrarTodo();

    const texto = JSON.stringify(await query('SELECT * FROM parts'));

    expect(texto).not.toMatch(/APP_USR|access_token|Bearer|cvv|card/i);
    expect(admin).toBeDefined();
  });
});
