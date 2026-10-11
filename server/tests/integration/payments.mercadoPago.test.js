import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let orden;
let gateway;

const cobrar = (metodo = 'MERCADO_PAGO', id = orden.id) => request(app).post(`/api/orders/${id}/payments`).set(auth(recepcion.token)).send({ method: metodo });
const consultar = (id) => request(app).post(`/api/payments/${id}/refresh`).set(auth(recepcion.token));
const cancelar = (id) => request(app).post(`/api/payments/${id}/cancel`).set(auth(recepcion.token));
const filaPago = async (id) => (await query('SELECT * FROM payments WHERE id = ?', [id]))[0];

beforeEach(async () => {
  await resetDatabase();
  gateway = new FakeGateway({ configured: true });
  setGateway(gateway);
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'MPG-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
});

afterAll(() => resetGateway());

describe('crear un cobro de Mercado Pago (US2, CA-3)', () => {
  it('test_crea_el_pago_pendiente_con_referencia_externa_enlace_e_importe_del_total', async () => {
    const res = await cobrar();

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ method: 'MERCADO_PAGO', status: 'PENDIENTE', amount: '1250.00', paidAt: null });
    const fila = await filaPago(res.body.data.id);
    expect(fila.external_reference).toBe(`motorix-pago-${res.body.data.id}`);
    expect(fila.checkout_url).toBe(res.body.data.checkoutUrl);
    expect(gateway.checkouts).toEqual([
      { reference: `motorix-pago-${res.body.data.id}`, amount: '1250.00', title: `Orden OS-${String(orden.id).padStart(6, '0')}` },
    ]);
  });

  it('test_sin_credenciales_responde_503_sin_crear_pago_y_los_demas_metodos_funcionan', async () => {
    setGateway(new FakeGateway({ configured: false }));

    const mp = await cobrar();
    const efectivo = await cobrar('EFECTIVO');

    expect(mp.status).toBe(503);
    expect(mp.body.error.code).toBe('PROVIDER_NOT_CONFIGURED');
    expect(efectivo.status).toBe(201);
    expect(await query('SELECT method FROM payments')).toEqual([{ method: 'EFECTIVO' }]);
  });

  it('test_si_el_proveedor_falla_no_queda_un_pago_a_medias_y_se_puede_reintentar', async () => {
    gateway.failCheckout = true;

    const fallo = await cobrar();

    expect(fallo.status).toBe(502);
    expect(fallo.body.error.code).toBe('PROVIDER_ERROR');
    expect(await query('SELECT id FROM payments')).toEqual([]);

    gateway.failCheckout = false;
    const reintento = await cobrar();
    expect(reintento.status).toBe(201);
    expect(await query('SELECT id FROM payments')).toHaveLength(1);
  });

  it('test_un_pago_pendiente_ya_es_el_pago_vigente', async () => {
    await cobrar();

    const otro = await cobrar('EFECTIVO');
    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(otro.status).toBe(409);
    expect(otro.body.error.details.status).toBe('PENDIENTE');
    expect(detalle.body.data.billing).toMatchObject({ collectionStatus: 'PENDIENTE', canCharge: false });
  });

  it('test_el_importe_del_cobro_conserva_el_total_con_el_que_se_creo_y_se_marca_desactualizado', async () => {
    const creado = await cobrar();
    await createService(orden.id, { description: 'Servicio extra', amount: '200.00' });

    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(creado.body.data.amount).toBe('1250.00');
    expect(detalle.body.data.billing).toMatchObject({ total: '1450.00', amountOutdated: true, collectionStatus: 'PENDIENTE' });
  });
});

describe('consultar el estado del cobro', () => {
  let pagoId;

  beforeEach(async () => {
    pagoId = (await cobrar()).body.data.id;
  });

  it('test_una_operacion_aprobada_pasa_a_pagado_y_guarda_la_referencia_externa', async () => {
    gateway.operations = [{ id: '98765', status: 'approved' }];

    const res = await consultar(pagoId);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ status: 'PAGADO', externalPaymentId: '98765' });
    expect(res.body.data.paidAt).toEqual(expect.any(String));
    expect(res.body.data.lastCheckedAt).toEqual(expect.any(String));
    expect(gateway.searches).toEqual([`motorix-pago-${pagoId}`]);
  });

  it('test_consultar_de_nuevo_un_pago_pagado_no_cambia_nada_ni_llama_al_proveedor', async () => {
    gateway.operations = [{ id: '98765', status: 'approved' }];
    const primera = await consultar(pagoId);
    gateway.operations = [{ id: '11111', status: 'rejected' }];

    const segunda = await consultar(pagoId);

    expect(segunda.status).toBe(200);
    expect(segunda.body.data).toMatchObject({ status: 'PAGADO', externalPaymentId: '98765', paidAt: primera.body.data.paidAt });
    expect(gateway.searches).toHaveLength(1);
    expect(await query("SELECT id FROM payments WHERE status = 'PAGADO'")).toHaveLength(1);
  });

  it.each(['rejected', 'cancelled'])('test_una_operacion_%s_pasa_a_rechazado_y_permite_cobrar_de_nuevo', async (estado) => {
    gateway.operations = [{ id: '1', status: estado }];

    const res = await consultar(pagoId);
    const nuevo = await cobrar('EFECTIVO');

    expect(res.body.data.status).toBe('RECHAZADO');
    expect(res.body.data.paidAt).toBeNull();
    expect(nuevo.status).toBe(201);
    expect(await query('SELECT status FROM payments ORDER BY id')).toEqual([{ status: 'RECHAZADO' }, { status: 'PAGADO' }]);
  });

  it.each([
    ['sin operaciones', []],
    ['pendiente', [{ id: '1', status: 'pending' }]],
    ['en proceso', [{ id: '1', status: 'in_process' }]],
  ])('test_%s_sigue_pendiente_y_actualiza_la_fecha_de_consulta', async (_nombre, operaciones) => {
    gateway.operations = operaciones;

    const res = await consultar(pagoId);

    expect(res.body.data.status).toBe('PENDIENTE');
    expect(res.body.data.lastCheckedAt).toEqual(expect.any(String));
  });

  it('test_si_el_proveedor_falla_el_estado_se_conserva', async () => {
    gateway.failSearch = true;

    const res = await consultar(pagoId);
    const despues = await filaPago(pagoId);

    expect(res.status).toBe(502);
    expect(despues.status).toBe('PENDIENTE');
    expect(despues.last_checked_at).toBeNull();
  });

  it('test_sin_credenciales_la_consulta_responde_503', async () => {
    setGateway(new FakeGateway({ configured: false }));

    const res = await consultar(pagoId);

    expect(res.status).toBe(503);
  });

  it('test_consultar_un_pago_cancelado_no_lo_reabre', async () => {
    await cancelar(pagoId);
    gateway.operations = [{ id: '1', status: 'approved' }];

    const res = await consultar(pagoId);

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('CANCELADO');
    expect(gateway.searches).toHaveLength(0);
  });

  it('test_consultar_un_pago_de_efectivo_lo_devuelve_sin_llamar_al_proveedor', async () => {
    await cancelar(pagoId);
    const efectivo = (await cobrar('EFECTIVO')).body.data;

    const res = await consultar(efectivo.id);

    expect(res.body.data.status).toBe('PAGADO');
    expect(gateway.searches).toHaveLength(0);
  });

  it('test_dos_consultas_simultaneas_aprobadas_dejan_un_solo_pago_pagado', async () => {
    gateway.operations = [{ id: '777', status: 'approved' }];

    const [a, b] = await Promise.all([consultar(pagoId), consultar(pagoId)]);

    expect([a.status, b.status]).toEqual([200, 200]);
    expect(await query("SELECT external_payment_id FROM payments WHERE status = 'PAGADO'")).toEqual([{ external_payment_id: '777' }]);
  });

  it('test_un_pago_inexistente_responde_404', async () => {
    expect((await consultar(999999)).status).toBe(404);
  });
});

describe('cancelar un cobro', () => {
  it('test_cancela_un_pendiente_se_conserva_y_libera_la_orden', async () => {
    const pago = (await cobrar()).body.data;

    const res = await cancelar(pago.id);
    const nuevo = await cobrar('TRANSFERENCIA');

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('CANCELADO');
    expect(nuevo.status).toBe(201);
    expect(await query('SELECT status FROM payments ORDER BY id')).toEqual([{ status: 'CANCELADO' }, { status: 'PAGADO' }]);
  });

  it.each([
    ['pagado', async () => (await cobrar('EFECTIVO')).body.data],
    ['rechazado', async () => {
      const pago = (await cobrar()).body.data;
      gateway.operations = [{ id: '1', status: 'rejected' }];
      await consultar(pago.id);
      return pago;
    }],
  ])('test_no_cancela_un_pago_%s', async (_estado, preparar) => {
    const pago = await preparar();

    const res = await cancelar(pago.id);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PAYMENT_NOT_CANCELLABLE');
  });

  it('test_un_pago_inexistente_responde_404', async () => {
    expect((await cancelar(999999)).status).toBe(404);
  });
});
