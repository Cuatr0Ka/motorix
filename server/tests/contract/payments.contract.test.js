import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createPayment,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;
let gateway;

const objetoPago = {
  id: expect.any(Number),
  orderId: expect.any(Number),
  orderFolio: expect.stringMatching(/^OS-\d{6}$/),
  amount: expect.stringMatching(/^\d+\.\d{2}$/),
  method: expect.stringMatching(/^(EFECTIVO|TARJETA|TRANSFERENCIA|MERCADO_PAGO)$/),
  status: expect.stringMatching(/^(PENDIENTE|PAGADO|RECHAZADO|CANCELADO)$/),
  createdAt: expect.any(String),
  createdBy: { id: expect.any(Number), name: expect.any(String) },
};

beforeEach(async () => {
  await resetDatabase();
  gateway = new FakeGateway({ configured: true });
  setGateway(gateway);
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'CTR-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
});

afterAll(() => resetGateway());

describe('POST /api/orders/:id/payments (contrato)', () => {
  it('test_efectivo_responde_201_con_el_objeto_pago', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO', reference: 'A1' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ ...objetoPago, status: 'PAGADO', amount: '1250.00', reference: 'A1' });
    expect(res.body.data.paidAt).toEqual(expect.any(String));
    expect(res.body.data).not.toHaveProperty('cardNumber');
  });

  it('test_mercado_pago_responde_201_pendiente_con_enlace_de_cobro', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ ...objetoPago, status: 'PENDIENTE', method: 'MERCADO_PAGO' });
    expect(res.body.data.checkoutUrl).toMatch(/^https:\/\/sandbox\.mercadopago\.simulado\/checkout\/motorix-pago-\d+$/);
    expect(res.body.data.paidAt).toBeNull();
  });

  it.each([
    [{ method: 'CHEQUE' }, 400, 'VALIDATION_ERROR'],
    [{ method: 'EFECTIVO', amount: 5 }, 422, 'AMOUNT_MISMATCH'],
  ])('test_el_cuerpo_%j_responde_%i_%s', async (cuerpo, estado, codigo) => {
    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send(cuerpo);

    expect(res.status).toBe(estado);
    expect(res.body.error).toMatchObject({ code: codigo, message: expect.any(String) });
  });

  it('test_un_segundo_cobro_responde_409_con_los_detalles_del_pago_existente', async () => {
    const primero = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });

    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'PAYMENT_ALREADY_EXISTS', details: { paymentId: primero.body.data.id, status: 'PAGADO' } });
  });
});

describe('consultas de pagos (contrato)', () => {
  it('test_el_listado_trae_cliente_vehiculo_y_meta', async () => {
    await createPayment(orden.id, recepcion.id);

    const res = await request(app).get('/api/payments').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data[0]).toMatchObject({ ...objetoPago, client: { id: expect.any(Number), name: expect.any(String) }, vehicle: { id: expect.any(Number), licensePlate: 'CTR-001-A' } });
  });

  it('test_el_detalle_y_la_lista_por_orden_responden_200', async () => {
    const pago = await createPayment(orden.id, recepcion.id);

    const detalle = await request(app).get(`/api/payments/${pago.id}`).set(auth(admin.token));
    const porOrden = await request(app).get(`/api/orders/${orden.id}/payments`).set(auth(admin.token));

    expect(detalle.status).toBe(200);
    expect(detalle.body.data).toMatchObject(objetoPago);
    expect(porOrden.body.data).toHaveLength(1);
  });

  it('test_methods_responde_la_lista_de_metodos_con_disponibilidad', async () => {
    const res = await request(app).get('/api/payments/methods').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data.methods).toEqual([
      { method: 'EFECTIVO', available: true },
      { method: 'TARJETA', available: true },
      { method: 'TRANSFERENCIA', available: true },
      { method: 'MERCADO_PAGO', available: true },
    ]);
  });

  it('test_un_identificador_invalido_responde_400_y_el_inexistente_404', async () => {
    expect((await request(app).get('/api/payments/abc').set(auth(admin.token))).status).toBe(400);
    expect((await request(app).get('/api/payments/999999').set(auth(admin.token))).status).toBe(404);
  });

  it('test_el_bloque_billing_del_detalle_de_la_orden_tiene_la_forma_del_contrato', async () => {
    await createPayment(orden.id, recepcion.id);

    const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(res.body.data.billing).toEqual({
      total: '1250.00',
      paidAmount: '1250.00',
      collectionStatus: 'PAGADO',
      amountOutdated: false,
      canCharge: false,
      payments: [expect.objectContaining(objetoPago)],
      ticket: null,
    });
  });
});

describe('refresh y cancel (contrato)', () => {
  let pago;

  beforeEach(async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });
    pago = res.body.data;
  });

  it('test_refresh_responde_200_con_el_pago_actualizado', async () => {
    gateway.operations = [{ id: '555', status: 'approved' }];

    const res = await request(app).post(`/api/payments/${pago.id}/refresh`).set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ ...objetoPago, status: 'PAGADO', externalPaymentId: '555' });
    expect(res.body.data.lastCheckedAt).toEqual(expect.any(String));
  });

  it('test_refresh_con_fallo_del_proveedor_responde_502_con_mensaje_en_espanol', async () => {
    gateway.failSearch = true;

    const res = await request(app).post(`/api/payments/${pago.id}/refresh`).set(auth(recepcion.token));

    expect(res.status).toBe(502);
    expect(res.body.error).toEqual({ code: 'PROVIDER_ERROR', message: 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.' });
  });

  it('test_cancel_responde_200_y_luego_409', async () => {
    const primera = await request(app).post(`/api/payments/${pago.id}/cancel`).set(auth(recepcion.token));
    const segunda = await request(app).post(`/api/payments/${pago.id}/cancel`).set(auth(recepcion.token));

    expect(primera.status).toBe(200);
    expect(primera.body.data.status).toBe('CANCELADO');
    expect(segunda.status).toBe(409);
    expect(segunda.body.error.code).toBe('PAYMENT_NOT_CANCELLABLE');
  });

  it('test_sin_credenciales_crear_un_cobro_de_mercado_pago_responde_503', async () => {
    setGateway(new FakeGateway({ configured: false }));
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'CTR-002-B' });
    const otra = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);

    const res = await request(app).post(`/api/orders/${otra.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });

    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('PROVIDER_NOT_CONFIGURED');
  });
});
