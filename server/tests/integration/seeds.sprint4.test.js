import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { buildTicketContent } from '../../services/ticketContent.js';
import { looksLikeCardNumber } from '../../services/paymentRules.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const app = createApp();
const contar = async (tabla) => Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total);
const sembrar = async () => {
  for (const archivo of ['001_initial_data.sql', '002_appointments_orders.sql', '003_history_inventory.sql', '004_payments_tickets.sql']) {
    await runSeedFile(archivo);
  }
};
const TABLAS = ['users', 'service_orders', 'order_services', 'order_labor', 'payments', 'tickets', 'parts', 'inventory_movements', 'maintenance'];
const conteos = async () => Object.fromEntries(await Promise.all(TABLAS.map(async (t) => [t, await contar(t)])));

/** Todas las claves (con su ruta) de un objeto, para comparar la forma de dos contenidos. */
function claves(objeto, prefijo = '') {
  if (Array.isArray(objeto)) return objeto.length > 0 ? claves(objeto[0], `${prefijo}[]`) : [];
  if (objeto === null || typeof objeto !== 'object') return [];
  return Object.entries(objeto).flatMap(([clave, valor]) => [`${prefijo}.${clave}`, ...claves(valor, `${prefijo}.${clave}`)]);
}

beforeEach(resetDatabase);

describe('seed del Sprint 4 (FR-026, SC-011)', () => {
  it('test_crea_pagos_en_los_cuatro_estados_y_con_los_cuatro_metodos', async () => {
    await sembrar();

    const estados = (await query('SELECT DISTINCT status FROM payments')).map((p) => p.status).sort();
    const metodos = (await query('SELECT DISTINCT method FROM payments')).map((p) => p.method).sort();

    expect(estados).toEqual(['CANCELADO', 'PAGADO', 'PENDIENTE', 'RECHAZADO']);
    expect(metodos).toEqual(['EFECTIVO', 'MERCADO_PAGO', 'TARJETA', 'TRANSFERENCIA']);
  });

  it('test_cada_orden_tiene_a_lo_sumo_un_pago_vigente_y_los_importes_coinciden_con_el_total', async () => {
    await sembrar();

    const vigentes = await query("SELECT order_id, COUNT(*) AS total FROM payments WHERE status IN ('PENDIENTE','PAGADO') GROUP BY order_id");
    for (const fila of vigentes) expect(Number(fila.total)).toBe(1);
    const incoherentes = await query(
      `SELECT p.id FROM payments p
        WHERE p.amount <> (SELECT COALESCE(SUM(s.amount),0) FROM order_services s WHERE s.order_id = p.order_id)
                        + (SELECT COALESCE(SUM(l.amount),0) FROM order_labor l WHERE l.order_id = p.order_id)`,
    );
    expect(incoherentes).toEqual([]);
    const sinFecha = await query("SELECT id FROM payments WHERE status = 'PAGADO' AND paid_at IS NULL");
    expect(sinFecha).toEqual([]);
  });

  it('test_no_hay_datos_de_tarjeta_ni_credenciales_en_los_pagos', async () => {
    await sembrar();

    const filas = await query('SELECT reference, external_reference, external_payment_id, checkout_url FROM payments');
    for (const fila of filas) {
      for (const valor of Object.values(fila)) {
        if (valor) expect(looksLikeCardNumber(valor)).toBe(false);
      }
      expect(JSON.stringify(fila)).not.toMatch(/APP_USR|TEST-|access_token|Bearer/i);
    }
  });

  it('test_crea_tickets_de_ordenes_cobradas_con_todos_los_campos_y_la_forma_del_sistema', async () => {
    await sembrar();

    const tickets = await query('SELECT t.id, t.order_id, t.payment_id, t.content, p.status, p.order_id AS pago_orden FROM tickets t JOIN payments p ON p.id = t.payment_id');
    expect(tickets.length).toBeGreaterThanOrEqual(5);
    const referencia = buildTicketContent({
      shop: { name: 'a', address: 'b', phone: 'c' },
      order: { id: 1, entryMileage: 1, serviceMileage: 2 },
      customer: { name: 'n', phone: 'p' },
      vehicle: { licensePlate: 'x', brand: 'b', model: 'm', year: 2020 },
      services: [{ description: 'd', amount: '1.00' }],
      parts: [{ code: 'c', name: 'n', unit: 'u', quantity: 1 }],
      labor: [{ description: 'd', amount: '1.00' }],
      payment: { method: 'EFECTIVO', status: 'PAGADO', paidAt: new Date(), reference: 'r' },
      now: new Date(),
    });
    for (const ticket of tickets) {
      expect(ticket.status).toBe('PAGADO');
      expect(ticket.pago_orden).toBe(ticket.order_id);
      const contenido = typeof ticket.content === 'string' ? JSON.parse(ticket.content) : ticket.content;
      const esperadas = claves(referencia).filter((c) => !c.startsWith('.services[]') || true);
      const obtenidas = new Set(claves(contenido));
      for (const clave of esperadas.filter((c) => !/\.(services|parts|labor)\[\]/.test(c))) expect(obtenidas.has(clave)).toBe(true);
      expect(contenido.totals.total).toMatch(/^\d+\.\d{2}$/);
      expect(contenido.payment.status).toBe('PAGADO');
      expect(contenido.generatedAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
      expect(JSON.stringify(contenido)).not.toMatch(/card|cvv|tarjeta número/i);
      const suma = Number(contenido.totals.services) + Number(contenido.totals.labor);
      expect(suma.toFixed(2)).toBe(Number(contenido.totals.total).toFixed(2));
    }
  });

  it('test_una_orden_cobrada_sin_ticket_permite_generarlo_desde_la_aplicacion', async () => {
    await sembrar();
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const [orden] = await query(
      `SELECT o.id FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id
        WHERE v.license_plate = 'PQR-678-F' AND o.reported_problem = 'Cambio de bujías'`,
    );

    const antes = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));
    const res = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    expect(antes.body.data.billing).toMatchObject({ collectionStatus: 'PAGADO', ticket: null });
    expect(res.status).toBe(201);
    expect(res.body.data.ticket.content.totals.total).toBe('1550.00');
  });

  it('test_el_panel_muestra_valores_en_todos_los_indicadores_desde_el_primer_arranque', async () => {
    await sembrar();
    const admin = await createUserWithToken('ADMIN');

    const res = await request(app).get('/api/dashboard').set(auth(admin.token));
    const { orders, appointments, maintenance, inventory, payments, recentActivity } = res.body.data;

    expect(res.status).toBe(200);
    expect(orders.attendedLast30Days).toBeGreaterThan(0);
    expect(orders.inRepair).toBeGreaterThan(0);
    expect(orders.pending).toBeGreaterThan(0);
    expect(orders.finishedAwaitingDelivery).toBeGreaterThan(0);
    expect(appointments.upcoming).toBeGreaterThan(0);
    expect(maintenance.upcoming).toBeGreaterThan(0);
    expect(maintenance.overdue).toBeGreaterThan(0);
    expect(inventory.lowStock).toBeGreaterThan(0);
    expect(inventory.outOfStock).toBeGreaterThan(0);
    expect(payments.ordersAwaitingPayment).toBeGreaterThan(0);
    expect(payments.pendingMercadoPago).toBeGreaterThan(0);
    expect(recentActivity.orderChanges.length).toBeGreaterThan(0);
    expect(recentActivity.payments.length).toBeGreaterThan(0);
    expect(recentActivity.inventoryMovements.length).toBeGreaterThan(0);
  });

  it('test_repetir_el_seed_tres_veces_no_duplica_pagos_ni_tickets', async () => {
    await sembrar();
    const primero = await conteos();

    await sembrar();
    await sembrar();

    expect(await conteos()).toEqual(primero);
    expect(primero.payments).toBeGreaterThanOrEqual(8);
    expect(primero.tickets).toBeGreaterThanOrEqual(5);
  });

  it('test_repetir_el_seed_conserva_los_cambios_hechos_despues_de_instalar', async () => {
    await sembrar();
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const [pendiente] = await query("SELECT id FROM payments WHERE status = 'PENDIENTE'");

    const cancelado = await request(app).post(`/api/payments/${pendiente.id}/cancel`).set(auth(recepcion.token));
    await sembrar();

    expect(cancelado.status).toBe(200);
    const [fila] = await query('SELECT status FROM payments WHERE id = ?', [pendiente.id]);
    expect(fila.status).toBe('CANCELADO');
    // La orden quedó libre: el seed no le vuelve a crear un cobro pendiente por encima del que ya existe.
    expect(await query("SELECT id FROM payments WHERE order_id = (SELECT order_id FROM payments WHERE id = ?) AND status IN ('PENDIENTE','PAGADO')", [pendiente.id])).toHaveLength(0);
  });
});
