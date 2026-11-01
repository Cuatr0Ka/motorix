import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const app = createApp();
let admin;
let recepcion;

const sembrar = async () => {
  for (const archivo of ['001_initial_data.sql', '002_appointments_orders.sql', '003_history_inventory.sql', '004_payments_tickets.sql']) {
    await runSeedFile(archivo);
  }
};

/** Foto de lo ya emitido: pagos (id, importe, estado, método) y contenido completo de los tickets. */
async function fotoDeLoEmitido() {
  const pagos = await query('SELECT id, order_id, amount, status, method FROM payments ORDER BY id');
  const tickets = (await query('SELECT id, order_id, payment_id, content FROM tickets ORDER BY id')).map((t) => ({
    ...t,
    content: typeof t.content === 'string' ? JSON.parse(t.content) : t.content,
  }));
  return { pagos, tickets };
}

const detalle = (id, user = recepcion) => request(app).get(`/api/orders/${id}`).set(auth(user.token));
const ticketDe = (orderId) => request(app).get(`/api/orders/${orderId}/ticket`).set(auth(recepcion.token));
const ponerPrecio = (partId, precio) => request(app).patch(`/api/parts/${partId}`).set(auth(admin.token)).send({ salePrice: precio, purchasePrice: '1.00' });

/** Una orden Entregada del seed con refacciones anteriores a los precios y su pago Pagado. */
async function ordenEntregadaConRefacciones() {
  const [fila] = await query(
    `SELECT o.id FROM service_orders o
      WHERE o.status = 'ENTREGADO'
        AND EXISTS (SELECT 1 FROM order_parts op WHERE op.order_id = o.id)
        AND EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id AND p.status = 'PAGADO')
        AND EXISTS (SELECT 1 FROM tickets t WHERE t.order_id = o.id)
      ORDER BY o.id LIMIT 1`,
  );
  return fila.id;
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  await sembrar();
});

describe('pagos y tickets del Sprint 4 (FR-008, FR-009, SC-003)', () => {
  it('test_las_lineas_sembradas_quedan_en_cero_y_no_suman_al_total_de_las_ordenes', async () => {
    const [{ total, enCero }] = await query('SELECT COUNT(*) AS total, SUM(unit_price = 0) AS enCero FROM order_parts');

    expect(Number(total)).toBeGreaterThan(0);
    expect(Number(enCero)).toBe(Number(total));
    const ordenId = await ordenEntregadaConRefacciones();
    const { totals, billing } = (await detalle(ordenId)).body.data;
    expect(totals.parts).toBe('0.00');
    expect(billing.total).toBe(totals.total);
    expect(billing.breakdown.subtotals.parts).toBe('0.00');
    expect(billing.breakdown.parts.every((p) => p.legacy && p.amount === '0.00')).toBe(true);
  });

  it('test_el_total_de_una_orden_sembrada_sigue_siendo_servicios_mas_mano_de_obra', async () => {
    const ordenId = await ordenEntregadaConRefacciones();

    const { totals } = (await detalle(ordenId)).body.data;

    expect(Number(totals.total)).toBe(Number(totals.services) + Number(totals.labor));
  });

  it('test_cambiar_los_precios_de_las_refacciones_no_altera_pagos_tickets_ni_totales', async () => {
    const antes = await fotoDeLoEmitido();
    const ordenId = await ordenEntregadaConRefacciones();
    const totalesAntes = (await detalle(ordenId)).body.data.totals;
    const partes = await query('SELECT id FROM parts');

    for (const parte of partes) expect((await ponerPrecio(parte.id, '999.00')).status).toBe(200);

    expect(await fotoDeLoEmitido()).toEqual(antes);
    expect((await detalle(ordenId)).body.data.totals).toEqual(totalesAntes);
  });

  it('test_el_ticket_anterior_se_devuelve_tal_como_se_emitio_sin_formato_ni_precios', async () => {
    const ordenId = await ordenEntregadaConRefacciones();
    const [{ content }] = await query('SELECT content FROM tickets WHERE order_id = ?', [ordenId]);
    const original = typeof content === 'string' ? JSON.parse(content) : content;

    const res = await ticketDe(ordenId);

    expect(res.status).toBe(200);
    expect(res.body.data.content).toEqual(original);
    expect(res.body.data.content).not.toHaveProperty('formatVersion');
    expect(res.body.data.content.totals).not.toHaveProperty('parts');
    for (const parte of res.body.data.content.parts) expect(parte).not.toHaveProperty('unitPrice');
  });

  it('test_una_orden_entregada_conserva_sus_importes_aunque_cambien_los_precios', async () => {
    const ordenId = await ordenEntregadaConRefacciones();
    const [{ id: pagoId, amount }] = await query("SELECT id, amount FROM payments WHERE order_id = ? AND status = 'PAGADO'", [ordenId]);
    const partes = await query('SELECT part_id AS id FROM order_parts WHERE order_id = ?', [ordenId]);

    for (const parte of partes) await ponerPrecio(parte.id, '5000.00');

    const [{ amount: despues }] = await query('SELECT amount FROM payments WHERE id = ?', [pagoId]);
    expect(despues).toBe(amount);
    const { billing } = (await detalle(ordenId)).body.data;
    expect(billing).toMatchObject({ paidAmount: amount, amountOutdated: false, amountDifference: '0.00' });
  });

  it('test_los_tickets_anteriores_se_pueden_listar_junto_con_los_nuevos', async () => {
    const res = await request(app).get('/api/tickets?pageSize=100').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThanOrEqual(5);
    for (const ticket of res.body.data) expect(ticket.total).toMatch(/^\d+\.\d{2}$/);
  });
});
