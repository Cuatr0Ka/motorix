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
  createPayableOrder,
  createPayment,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let vehiculo;
let orden;
let seq = 0;

const cobrar = (cuerpo, user = recepcion, id = orden.id) => request(app).post(`/api/orders/${id}/payments`).set(auth(user.token)).send(cuerpo);
const pagosEnBase = (id = orden.id) => query('SELECT method, status, amount, reference, paid_at FROM payments WHERE order_id = ? ORDER BY id', [id]);

async function nuevaOrden(estado = 'TERMINADO', { conServicio = true } = {}) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `PAG-${String(seq).padStart(3, '0')}-Z` });
  if (estado === 'TERMINADO' && conServicio) return createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  const o = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: estado });
  if (conServicio) await createService(o.id);
  return o;
}

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  setGateway(new FakeGateway({ configured: false }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'PAG-000-Z' }));
  orden = await createPayableOrder(vehiculo.id, recepcion.id, mecanico.id);
});

afterAll(() => resetGateway());

describe('registrar el pago de una orden (US1, CA-1, CA-2)', () => {
  it.each([['EFECTIVO'], ['TARJETA'], ['TRANSFERENCIA']])('test_cobra_con_%s_queda_pagado_por_el_total', async (metodo) => {
    const res = await cobrar({ method: metodo, reference: 'REF-123' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      orderId: orden.id,
      amount: '1250.00',
      method: metodo,
      status: 'PAGADO',
      reference: 'REF-123',
      createdBy: { id: recepcion.id },
    });
    expect(res.body.data.paidAt).toEqual(expect.any(String));
    const [fila] = await pagosEnBase();
    expect(fila).toMatchObject({ method: metodo, status: 'PAGADO', amount: '1250.00' });
    expect(fila.paid_at).not.toBeNull();
  });

  it('test_el_administrador_tambien_puede_cobrar', async () => {
    const res = await cobrar({ method: 'EFECTIVO' }, admin);

    expect(res.status).toBe(201);
    expect(res.body.data.createdBy.id).toBe(admin.id);
  });

  it('test_acepta_el_importe_igual_al_total', async () => {
    const res = await cobrar({ method: 'EFECTIVO', amount: '1250.00' });

    expect(res.status).toBe(201);
    expect(res.body.data.amount).toBe('1250.00');
  });

  it('test_rechaza_un_importe_distinto_e_informa_el_total', async () => {
    const res = await cobrar({ method: 'EFECTIVO', amount: 1000 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('AMOUNT_MISMATCH');
    expect(res.body.error.details).toEqual({ total: '1250.00' });
    expect(await pagosEnBase()).toEqual([]);
  });

  it('test_una_orden_entregada_tambien_se_cobra', async () => {
    const entregada = await nuevaOrden('ENTREGADO');

    const res = await cobrar({ method: 'TRANSFERENCIA', reference: 'CLAVE-ABC' }, recepcion, entregada.id);

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('PAGADO');
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])('test_no_cobra_una_orden_%s', async (estado) => {
    const abierta = await nuevaOrden(estado);

    const res = await cobrar({ method: 'EFECTIVO' }, recepcion, abierta.id);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_NOT_PAYABLE');
    expect(await pagosEnBase(abierta.id)).toEqual([]);
  });

  it('test_no_cobra_una_orden_con_total_cero', async () => {
    const vacia = await nuevaOrden('TERMINADO', { conServicio: false });

    const res = await cobrar({ method: 'EFECTIVO' }, recepcion, vacia.id);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('NOTHING_TO_CHARGE');
  });

  it('test_no_admite_un_segundo_pago_vigente', async () => {
    const primero = await cobrar({ method: 'EFECTIVO' });

    const segundo = await cobrar({ method: 'TARJETA' });

    expect(segundo.status).toBe(409);
    expect(segundo.body.error.code).toBe('PAYMENT_ALREADY_EXISTS');
    expect(segundo.body.error.details).toEqual({ paymentId: primero.body.data.id, status: 'PAGADO' });
    expect(await pagosEnBase()).toHaveLength(1);
  });

  it('test_una_orden_inexistente_responde_404', async () => {
    const res = await cobrar({ method: 'EFECTIVO' }, recepcion, 999999);

    expect(res.status).toBe(404);
  });
});

describe('datos de tarjeta y validaciones (RN-14)', () => {
  it.each(['4111111111111111', '4111 1111 1111 1111', '5555-5555-5555-4444', 'tarjeta 378282246310005'])(
    'test_rechaza_la_referencia_con_numero_de_tarjeta_%s',
    async (texto) => {
      const res = await cobrar({ method: 'TARJETA', reference: texto });

      expect(res.status).toBe(400);
      expect(res.body.error.details[0].field).toBe('reference');
      expect(await pagosEnBase()).toEqual([]);
    },
  );

  it('test_acepta_un_folio_de_terminal_normal', async () => {
    const res = await cobrar({ method: 'TARJETA', reference: 'Folio terminal 48213' });

    expect(res.status).toBe(201);
  });

  it.each([
    [{ method: 'CHEQUE' }, 'method'],
    [{}, 'method'],
    [{ method: 'EFECTIVO', amount: -5 }, 'amount'],
    [{ method: 'EFECTIVO', amount: 'mucho' }, 'amount'],
    [{ method: 'EFECTIVO', amount: 10.555 }, 'amount'],
    [{ method: 'EFECTIVO', reference: 'x'.repeat(101) }, 'reference'],
  ])('test_rechaza_con_400_el_cuerpo_%j', async (cuerpo, campo) => {
    const res = await cobrar(cuerpo);

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });

  it.each(['cardNumber', 'cvv', 'expiry', 'cardholder', 'pan'])('test_rechaza_el_campo_de_tarjeta_%s', async (campo) => {
    const res = await cobrar({ method: 'TARJETA', [campo]: '4111111111111111' });

    expect(res.status).toBe(400);
    expect(await pagosEnBase()).toEqual([]);
  });

  it('test_la_tabla_de_pagos_no_tiene_columnas_de_tarjeta', async () => {
    const columnas = (await query("SELECT column_name AS nombre FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'payments'")).map(
      (c) => c.nombre.toLowerCase(),
    );

    for (const prohibida of ['card_number', 'cvv', 'pan', 'expiry', 'cardholder', 'security_code', 'access_token']) {
      expect(columnas).not.toContain(prohibida);
    }
  });

  it('test_la_base_rechaza_un_pago_en_efectivo_pendiente_y_un_importe_cero', async () => {
    await expect(
      query("INSERT INTO payments (order_id, amount, method, status, created_by) VALUES (?, 100, 'EFECTIVO', 'PENDIENTE', ?)", [orden.id, admin.id]),
    ).rejects.toThrow();
    await expect(
      query("INSERT INTO payments (order_id, amount, method, status, paid_at, created_by) VALUES (?, 0, 'EFECTIVO', 'PAGADO', NOW(), ?)", [orden.id, admin.id]),
    ).rejects.toThrow();
  });
});

describe('bloque de cobro en el detalle de la orden (FR-001)', () => {
  const detalle = (user = recepcion, id = orden.id) => request(app).get(`/api/orders/${id}`).set(auth(user.token));

  it('test_sin_pago_muestra_el_total_y_permite_cobrar', async () => {
    const res = await detalle();

    expect(res.body.data.billing).toEqual({
      total: '1250.00',
      paidAmount: '0.00',
      collectionStatus: 'SIN_COBRAR',
      amountOutdated: false,
      canCharge: true,
      payments: [],
      ticket: null,
    });
  });

  it('test_con_pago_muestra_pagado_y_ya_no_permite_cobrar', async () => {
    await cobrar({ method: 'EFECTIVO' });

    const res = await detalle(admin);

    expect(res.body.data.billing).toMatchObject({ collectionStatus: 'PAGADO', paidAmount: '1250.00', canCharge: false, amountOutdated: false });
    expect(res.body.data.billing.payments).toHaveLength(1);
  });

  it('test_marca_el_importe_desactualizado_si_el_total_cambia_despues_del_cobro', async () => {
    await cobrar({ method: 'EFECTIVO' });
    await createService(orden.id, { description: 'Servicio extra', amount: '100.00' });

    const res = await detalle();

    expect(res.body.data.billing).toMatchObject({ total: '1350.00', paidAmount: '1250.00', amountOutdated: true });
  });

  it('test_el_total_no_incluye_las_refacciones', async () => {
    const res = await detalle();

    expect(res.body.data.totals.total).toBe('1250.00');
    expect(res.body.data.billing.total).toBe('1250.00');
  });

  it('test_una_orden_abierta_no_se_puede_cobrar', async () => {
    const abierta = await nuevaOrden('EN_REPARACION');

    const res = await detalle(recepcion, abierta.id);

    expect(res.body.data.billing).toMatchObject({ canCharge: false, collectionStatus: 'SIN_COBRAR' });
  });

  it('test_un_pago_rechazado_no_cuenta_como_vigente_y_permite_cobrar_de_nuevo', async () => {
    await createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'RECHAZADO' });

    const antes = await detalle();
    const cobro = await cobrar({ method: 'EFECTIVO' });
    const despues = await detalle();

    expect(antes.body.data.billing).toMatchObject({ canCharge: true, collectionStatus: 'SIN_COBRAR' });
    expect(cobro.status).toBe(201);
    expect(despues.body.data.billing.payments.map((p) => p.status)).toEqual(['PAGADO', 'RECHAZADO']);
  });
});

describe('consulta de pagos', () => {
  let otraOrden;

  beforeEach(async () => {
    otraOrden = await nuevaOrden('ENTREGADO');
    await createPayment(orden.id, recepcion.id, { method: 'EFECTIVO' });
    await createPayment(otraOrden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'PENDIENTE' });
  });

  const listar = (q = '', user = recepcion) => request(app).get(`/api/payments${q}`).set(auth(user.token));

  it('test_lista_los_pagos_del_mas_reciente_al_mas_antiguo_con_meta', async () => {
    const res = await listar();

    expect(res.status).toBe(200);
    expect(res.body.data.map((p) => p.method)).toEqual(['MERCADO_PAGO', 'EFECTIVO']);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 2 });
    expect(res.body.data[0]).toMatchObject({ orderFolio: expect.stringMatching(/^OS-\d{6}$/), client: { name: expect.any(String) }, vehicle: { licensePlate: expect.any(String) } });
  });

  it('test_filtra_por_estado_y_por_metodo', async () => {
    expect((await listar('?status=PENDIENTE')).body.data).toHaveLength(1);
    expect((await listar('?method=EFECTIVO')).body.data[0].method).toBe('EFECTIVO');
    expect((await listar('?status=PAGADO&method=MERCADO_PAGO')).body.data).toEqual([]);
    expect((await listar('?status=XX')).status).toBe(400);
  });

  it('test_busca_por_folio_de_orden_por_cliente_y_por_placa', async () => {
    expect((await listar(`?search=OS-${orden.id}`)).body.data.map((p) => p.orderId)).toEqual([orden.id]);
    expect((await listar('?search=PAG-000')).body.data.map((p) => p.orderId)).toEqual([orden.id]);
    expect((await listar('?search=nadie-existe')).body.data).toEqual([]);
  });

  it('test_lista_los_pagos_de_una_orden_y_ve_el_detalle', async () => {
    const porOrden = await request(app).get(`/api/orders/${orden.id}/payments`).set(auth(admin.token));
    const [{ id }] = porOrden.body.data;
    const uno = await request(app).get(`/api/payments/${id}`).set(auth(admin.token));

    expect(porOrden.status).toBe(200);
    expect(porOrden.body.data).toHaveLength(1);
    expect(uno.body.data).toMatchObject({ id, orderId: orden.id });
    expect((await request(app).get('/api/payments/999999').set(auth(admin.token))).status).toBe(404);
    expect((await request(app).get('/api/orders/999999/payments').set(auth(admin.token))).status).toBe(404);
  });

  it('test_no_existen_operaciones_para_eliminar_ni_editar_pagos', async () => {
    const [{ id }] = (await listar()).body.data;

    for (const metodo of ['delete', 'put', 'patch']) {
      const res = await request(app)[metodo](`/api/payments/${id}`).set(auth(admin.token)).send({});
      expect(res.status).toBe(404);
    }
    expect(await query('SELECT COUNT(*) AS total FROM payments')).toEqual([{ total: 2 }]);
  });

  it('test_los_metodos_disponibles_indican_si_mercado_pago_esta_configurado', async () => {
    const sin = await request(app).get('/api/payments/methods').set(auth(recepcion.token));
    setGateway(new FakeGateway({ configured: true }));
    const con = await request(app).get('/api/payments/methods').set(auth(recepcion.token));

    expect(sin.body.data.methods.map((m) => m.method)).toEqual(['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO']);
    expect(sin.body.data.methods.find((m) => m.method === 'MERCADO_PAGO')).toMatchObject({ available: false, reason: expect.any(String) });
    expect(sin.body.data.methods.filter((m) => m.available)).toHaveLength(3);
    expect(con.body.data.methods.every((m) => m.available)).toBe(true);
  });
});
