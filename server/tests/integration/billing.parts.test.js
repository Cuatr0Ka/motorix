import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createOrder,
  createOrderPart,
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
let seq = 0;

const cobrar = (cuerpo, id = orden.id, user = recepcion) => request(app).post(`/api/orders/${id}/payments`).set(auth(user.token)).send(cuerpo);
const detalle = (user = recepcion, id = orden.id) => request(app).get(`/api/orders/${id}`).set(auth(user.token));
const pagosEnBase = (id = orden.id) => query('SELECT id, method, status, amount FROM payments WHERE order_id = ? ORDER BY id', [id]);

/** Orden Terminada con servicio 850.00 y mano de obra 400.00 (total 1250.00). */
async function ordenCobrable() {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `BIL-${String(seq).padStart(3, '0')}-Z` });
  return createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
}

/** Orden Terminada sin servicios ni mano de obra. */
async function ordenSinConceptos() {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `BIL-${String(seq).padStart(3, '0')}-Z` });
  return createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
}

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  gateway = new FakeGateway({ configured: true });
  setGateway(gateway);
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  orden = await ordenCobrable();
  parte = await createPart(admin.id, { code: 'BIL-REF', name: 'Balatas', unit: 'juego', stock: 10, salePrice: 180 });
});

afterAll(() => resetGateway());

describe('desglose del cobro (FR-023)', () => {
  it('test_el_cobro_incluye_el_total_y_el_desglose_de_servicios_mano_de_obra_y_refacciones', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 2, '180.00');

    const { billing } = (await detalle()).body.data;

    expect(billing).toMatchObject({ total: '1610.00', paidAmount: '0.00', collectionStatus: 'SIN_COBRAR', amountOutdated: false, amountDifference: '0.00', canCharge: true });
    expect(billing.breakdown).toEqual({
      services: [{ id: expect.any(Number), description: 'Cambio de balatas', amount: '850.00' }],
      labor: [{ id: expect.any(Number), description: 'Mano de obra frenos', amount: '400.00' }],
      parts: [{ id: expect.any(Number), code: 'BIL-REF', name: 'Balatas', unit: 'juego', quantity: 2, unitPrice: '180.00', amount: '360.00', legacy: false }],
      subtotals: { services: '850.00', labor: '400.00', parts: '360.00' },
    });
  });

  it('test_una_linea_anterior_a_los_precios_aparece_marcada_y_sin_importe', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 3);

    const { billing } = (await detalle()).body.data;

    expect(billing.total).toBe('1250.00');
    expect(billing.breakdown.parts[0]).toMatchObject({ quantity: 3, unitPrice: '0.00', amount: '0.00', legacy: true });
    expect(billing.breakdown.subtotals.parts).toBe('0.00');
  });

  it('test_el_desglose_lo_reciben_administracion_y_recepcion_pero_no_el_mecanico', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '180.00');

    for (const user of [admin, recepcion]) {
      expect((await detalle(user)).body.data.billing.breakdown.subtotals.parts).toBe('180.00');
    }
    expect((await detalle(mecanico)).body.data).not.toHaveProperty('billing');
  });
});

describe('cobrar el total con refacciones (FR-006, FR-021)', () => {
  it('test_el_pago_nace_por_el_total_con_refacciones', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 2, '180.00');

    const res = await cobrar({ method: 'EFECTIVO' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ amount: '1610.00', status: 'PAGADO' });
    expect((await detalle()).body.data.billing).toMatchObject({ paidAmount: '1610.00', collectionStatus: 'PAGADO', amountDifference: '0.00' });
  });

  it('test_un_importe_distinto_al_total_con_refacciones_se_rechaza_con_el_total_vigente', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 2, '180.00');

    const res = await cobrar({ method: 'EFECTIVO', amount: '1250.00' });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('AMOUNT_MISMATCH');
    expect(res.body.error.details).toEqual({ total: '1610.00' });
    expect(await pagosEnBase()).toEqual([]);
  });

  it('test_un_importe_igual_al_total_con_refacciones_se_acepta', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 2, '180.00');

    const res = await cobrar({ method: 'TARJETA', amount: 1610 });

    expect(res.status).toBe(201);
    expect(res.body.data.amount).toBe('1610.00');
  });

  it('test_una_orden_con_solo_refacciones_con_precio_es_cobrable', async () => {
    const soloPiezas = await ordenSinConceptos();
    await createOrderPart(soloPiezas.id, parte.id, admin.id, 1, '180.00');

    const antes = (await detalle(recepcion, soloPiezas.id)).body.data.billing;
    const res = await cobrar({ method: 'EFECTIVO' }, soloPiezas.id);

    expect(antes).toMatchObject({ total: '180.00', canCharge: true });
    expect(res.status).toBe(201);
    expect(res.body.data.amount).toBe('180.00');
  });

  it('test_una_orden_sin_ningun_concepto_responde_422_NOTHING_TO_CHARGE', async () => {
    const vacia = await ordenSinConceptos();

    const antes = (await detalle(recepcion, vacia.id)).body.data.billing;
    const res = await cobrar({ method: 'EFECTIVO' }, vacia.id);

    expect(antes).toMatchObject({ total: '0.00', canCharge: false });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('NOTHING_TO_CHARGE');
    expect(res.body.error.message).toBe('La orden no tiene nada que cobrar: el total es cero.');
  });

  it('test_una_orden_con_solo_lineas_anteriores_sin_otros_conceptos_no_es_cobrable', async () => {
    const soloAnteriores = await ordenSinConceptos();
    await createOrderPart(soloAnteriores.id, parte.id, admin.id, 5);

    const res = await cobrar({ method: 'EFECTIVO' }, soloAnteriores.id);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('NOTHING_TO_CHARGE');
  });
});

describe('Mercado Pago con refacciones (FR-011)', () => {
  it('test_el_importe_enviado_al_proveedor_es_el_total_con_refacciones', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 2, '180.00');

    const res = await cobrar({ method: 'MERCADO_PAGO' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ amount: '1610.00', status: 'PENDIENTE' });
    expect(gateway.checkouts).toHaveLength(1);
    expect(gateway.checkouts[0].amount).toBe('1610.00');
  });
});

describe('pago de Mercado Pago pendiente y desfasado (FR-012)', () => {
  let pendiente;

  beforeEach(async () => {
    pendiente = (await cobrar({ method: 'MERCADO_PAGO' })).body.data;
  });

  it('test_un_pago_pendiente_con_el_importe_vigente_no_esta_desfasado', async () => {
    const { billing } = (await detalle()).body.data;

    expect(billing).toMatchObject({ amountOutdated: false, collectionStatus: 'PENDIENTE', canCharge: false });
  });

  it('test_al_cambiar_el_total_el_pago_pendiente_queda_desfasado_y_el_nuevo_cobro_lo_indica', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '100.00');

    const { billing } = (await detalle()).body.data;
    const intento = await cobrar({ method: 'EFECTIVO' });

    expect(billing).toMatchObject({ total: '1350.00', amountOutdated: true, collectionStatus: 'PENDIENTE' });
    expect(intento.status).toBe(409);
    expect(intento.body.error.code).toBe('PAYMENT_ALREADY_EXISTS');
    expect(intento.body.error.details).toEqual({ paymentId: pendiente.id, status: 'PENDIENTE', outdated: true });
  });

  it('test_el_aviso_de_pago_existente_indica_que_no_esta_desfasado_si_el_importe_coincide', async () => {
    const intento = await cobrar({ method: 'EFECTIVO' });

    expect(intento.status).toBe(409);
    expect(intento.body.error.details).toEqual({ paymentId: pendiente.id, status: 'PENDIENTE', outdated: false });
  });

  it('test_cancelar_el_pago_desfasado_conserva_el_historial_y_permite_cobrar_el_total_vigente', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '100.00');

    const cancelado = await request(app).post(`/api/payments/${pendiente.id}/cancel`).set(auth(recepcion.token));
    const nuevo = await cobrar({ method: 'MERCADO_PAGO' });

    expect(cancelado.status).toBe(200);
    expect(cancelado.body.data.status).toBe('CANCELADO');
    expect(nuevo.status).toBe(201);
    expect(nuevo.body.data.amount).toBe('1350.00');
    expect(gateway.checkouts.at(-1).amount).toBe('1350.00');
    expect((await pagosEnBase()).map((p) => [p.status, p.amount])).toEqual([
      ['CANCELADO', '1250.00'],
      ['PENDIENTE', '1350.00'],
    ]);
  });

  it('test_el_sistema_no_cancela_ni_crea_pagos_por_si_solo_al_cambiar_el_total', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '100.00');

    await detalle();
    await detalle(admin);

    expect((await pagosEnBase()).map((p) => [p.status, p.amount])).toEqual([['PENDIENTE', '1250.00']]);
  });

  it('test_aprobacion_tardia_el_pago_queda_pagado_con_su_importe_original_y_se_muestra_la_diferencia', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '100.00');
    gateway.operations = [{ id: 'MP-777', status: 'approved' }];

    const refresh = await request(app).post(`/api/payments/${pendiente.id}/refresh`).set(auth(recepcion.token));
    const { billing } = (await detalle()).body.data;

    expect(refresh.status).toBe(200);
    expect(refresh.body.data).toMatchObject({ status: 'PAGADO', amount: '1250.00' });
    expect(billing).toMatchObject({
      total: '1350.00',
      paidAmount: '1250.00',
      collectionStatus: 'PAGADO',
      amountOutdated: true,
      amountDifference: '100.00',
      canCharge: false,
    });
    expect(await pagosEnBase()).toHaveLength(1);
  });

  it('test_la_diferencia_no_se_cobra_sola_ni_se_crea_otro_pago', async () => {
    await createOrderPart(orden.id, parte.id, admin.id, 1, '100.00');
    gateway.operations = [{ id: 'MP-778', status: 'approved' }];
    await request(app).post(`/api/payments/${pendiente.id}/refresh`).set(auth(recepcion.token));

    const intento = await cobrar({ method: 'EFECTIVO' });

    expect(intento.status).toBe(409);
    expect(intento.body.error.code).toBe('PAYMENT_ALREADY_EXISTS');
    expect(await pagosEnBase()).toHaveLength(1);
  });
});

describe('permisos del cobro', () => {
  it('test_el_mecanico_recibe_403_al_consultar_cobrar_cancelar_o_actualizar_un_pago', async () => {
    const pendiente = (await cobrar({ method: 'MERCADO_PAGO' })).body.data;
    const como = (metodo, ruta) => request(app)[metodo](ruta).set(auth(mecanico.token));

    const respuestas = await Promise.all([
      como('get', `/api/orders/${orden.id}/payments`),
      como('get', `/api/payments/${pendiente.id}`),
      como('post', `/api/payments/${pendiente.id}/cancel`),
      como('post', `/api/payments/${pendiente.id}/refresh`),
      request(app).post(`/api/orders/${orden.id}/payments`).set(auth(mecanico.token)).send({ method: 'EFECTIVO' }),
    ]);

    expect(respuestas.map((r) => r.status)).toEqual([403, 403, 403, 403, 403]);
    expect((await pagosEnBase())[0].status).toBe('PENDIENTE');
  });
});
