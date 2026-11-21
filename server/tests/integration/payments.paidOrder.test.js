import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createPart,
  createPayableOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let gateway;
let orden;
let parte;
let linea;
let seq = 0;

const agregar = (user, cuerpo, id = orden.id) => request(app).post(`/api/orders/${id}/parts`).set(auth(user.token)).send(cuerpo);
const corregir = (user, lineId, cantidad, id = orden.id) =>
  request(app).patch(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token)).send({ quantity: cantidad });
const quitar = (user, lineId, id = orden.id) => request(app).delete(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token));
const cobrar = (metodo = 'EFECTIVO', id = orden.id) => request(app).post(`/api/orders/${id}/payments`).set(auth(recepcion.token)).send({ method: metodo });
const stockDe = async () => (await query('SELECT stock FROM parts WHERE id = ?', [parte.id]))[0].stock;
const movimientos = async () => (await query('SELECT COUNT(*) AS n FROM inventory_movements WHERE part_id = ?', [parte.id]))[0].n;
const lineasEnBase = (id = orden.id) => query('SELECT part_id AS partId, quantity, unit_price AS unitPrice FROM order_parts WHERE order_id = ?', [id]);

async function nuevaOrden() {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `PAI-${String(seq).padStart(3, '0')}-Z` });
  return createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
}

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  gateway = new FakeGateway({ configured: true });
  setGateway(gateway);
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  orden = await nuevaOrden();
  parte = await createPart(admin.id, { code: 'PAI-REF', name: 'Balatas', stock: 10, salePrice: 180 });
  linea = (await agregar(mecanico, { partId: parte.id, quantity: 2 })).body.data.item;
});

afterAll(() => resetGateway());

describe('orden con un pago Pagado (FR-026)', () => {
  beforeEach(async () => {
    expect((await cobrar('EFECTIVO')).status).toBe(201);
  });

  it('test_agregar_cambiar_la_cantidad_y_quitar_responden_409_ORDER_ALREADY_PAID', async () => {
    const otra = await createPart(admin.id, { code: 'PAI-OTRA', stock: 5, salePrice: 50 });

    const agrega = await agregar(admin, { partId: otra.id, quantity: 1 });
    const mismaParte = await agregar(mecanico, { partId: parte.id, quantity: 1 });
    const corrige = await corregir(mecanico, linea.id, 3);
    const quita = await quitar(admin, linea.id);

    for (const res of [agrega, mismaParte, corrige, quita]) {
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_ALREADY_PAID');
      expect(res.body.error.message).toBe('La orden ya está cobrada: no se pueden modificar las refacciones.');
    }
  });

  it('test_no_cambia_ninguna_linea_ni_el_stock_ni_los_movimientos', async () => {
    const stockAntes = await stockDe();
    const movimientosAntes = await movimientos();
    const lineasAntes = await lineasEnBase();

    await agregar(admin, { partId: parte.id, quantity: 1 });
    await corregir(admin, linea.id, 5);
    await quitar(admin, linea.id);

    expect(await lineasEnBase()).toEqual(lineasAntes);
    expect(await stockDe()).toBe(stockAntes);
    expect(await movimientos()).toBe(movimientosAntes);
  });

  it('test_el_pago_conserva_su_importe_y_el_total_de_la_orden_no_cambia', async () => {
    await agregar(admin, { partId: parte.id, quantity: 1 });

    const { billing } = (await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token))).body.data;

    expect(billing).toMatchObject({ total: '1610.00', paidAmount: '1610.00', amountDifference: '0.00', amountOutdated: false });
  });

  it('test_disminuir_la_cantidad_tampoco_se_permite_con_un_pago_pagado', async () => {
    const res = await corregir(admin, linea.id, 1);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_ALREADY_PAID');
  });

  it('test_el_error_de_orden_entregada_tiene_prioridad_sobre_el_de_orden_cobrada', async () => {
    await query("UPDATE service_orders SET status = 'ENTREGADO', delivered_at = NOW() WHERE id = ?", [orden.id]);

    const res = await agregar(admin, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
  });
});

describe('orden con un pago Pendiente (FR-026, FR-012)', () => {
  beforeEach(async () => {
    expect((await cobrar('MERCADO_PAGO')).status).toBe(201);
  });

  it('test_los_tres_cambios_se_permiten_y_el_pago_queda_desfasado', async () => {
    const otra = await createPart(admin.id, { code: 'PAI-OTRA', stock: 5, salePrice: 50 });

    const agrega = await agregar(admin, { partId: otra.id, quantity: 1 });
    const corrige = await corregir(admin, linea.id, 3);
    const { billing } = (await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token))).body.data;

    expect(agrega.status).toBe(201);
    expect(corrige.status).toBe(200);
    expect(billing).toMatchObject({ collectionStatus: 'PENDIENTE', amountOutdated: true, total: '1840.00' });
    expect(Number(billing.payments[0].amount)).toBe(1610);

    const quita = await quitar(admin, linea.id);
    expect(quita.status).toBe(200);
  });

  it('test_un_pago_cancelado_o_rechazado_no_bloquea_los_cambios', async () => {
    const pendiente = (await query("SELECT id FROM payments WHERE order_id = ? AND status = 'PENDIENTE'", [orden.id]))[0];
    await request(app).post(`/api/payments/${pendiente.id}/cancel`).set(auth(recepcion.token));

    const res = await corregir(admin, linea.id, 4);

    expect(res.status).toBe(200);
  });
});

describe('cobrar y modificar refacciones al mismo tiempo (FR-010)', () => {
  /** Total que realmente tiene la orden: servicios + mano de obra + refacciones en la base. */
  async function totalEnBase(id) {
    const [fila] = await query(
      `SELECT (SELECT COALESCE(SUM(amount), 0) FROM order_services WHERE order_id = ?)
            + (SELECT COALESCE(SUM(amount), 0) FROM order_labor WHERE order_id = ?)
            + (SELECT COALESCE(SUM(quantity * unit_price), 0) FROM order_parts WHERE order_id = ?) AS total`,
      [id, id, id],
    );
    return Number(fila.total);
  }

  it('test_el_pago_nunca_queda_por_debajo_del_total_de_la_orden', async () => {
    const resultados = new Set();

    for (let i = 0; i < 8; i += 1) {
      const o = await nuevaOrden();
      const p = await createPart(admin.id, { code: `PAI-RAC-${i}`, stock: 5, salePrice: 100 });

      const [pago, alta] = await Promise.all([cobrar('EFECTIVO', o.id), agregar(admin, { partId: p.id, quantity: 1 }, o.id)]);

      expect(pago.status).toBe(201);
      expect([201, 409]).toContain(alta.status);
      if (alta.status === 409) expect(alta.body.error.code).toBe('ORDER_ALREADY_PAID');
      const [{ amount }] = await query("SELECT amount FROM payments WHERE order_id = ? AND status = 'PAGADO'", [o.id]);
      expect(Number(amount)).toBe(await totalEnBase(o.id));
      resultados.add(alta.status);
    }

    expect(resultados.size).toBeGreaterThanOrEqual(1);
  });
});
