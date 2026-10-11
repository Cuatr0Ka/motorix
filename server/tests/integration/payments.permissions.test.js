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
let pago;

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'PER-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  pago = await createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'PENDIENTE', externalReference: 'motorix-pago-x' });
});

afterAll(() => resetGateway());

describe('permisos de pagos (FR-021, SC-008)', () => {
  const rutas = () => [
    ['get', '/api/payments/methods'],
    ['get', '/api/payments'],
    ['get', `/api/payments/${pago.id}`],
    ['post', `/api/payments/${pago.id}/refresh`],
    ['post', `/api/payments/${pago.id}/cancel`],
    ['get', `/api/orders/${orden.id}/payments`],
    ['post', `/api/orders/${orden.id}/payments`, { method: 'EFECTIVO' }],
  ];

  it('test_el_mecanico_recibe_403_en_todas_las_rutas_de_pagos', async () => {
    for (const [metodo, ruta, cuerpo] of rutas()) {
      const res = await request(app)[metodo](ruta).set(auth(mecanico.token)).send(cuerpo ?? {});

      expect([ruta, res.status]).toEqual([ruta, 403]);
      expect(res.body.error.code).toBe('FORBIDDEN');
    }
  });

  it('test_sin_sesion_todas_las_rutas_responden_401', async () => {
    for (const [metodo, ruta, cuerpo] of rutas()) {
      const res = await request(app)[metodo](ruta).send(cuerpo ?? {});

      expect([ruta, res.status]).toEqual([ruta, 401]);
    }
  });

  it('test_el_mecanico_no_cambia_nada_aunque_la_solicitud_no_venga_de_la_interfaz', async () => {
    await request(app).post(`/api/payments/${pago.id}/cancel`).set(auth(mecanico.token));
    await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(mecanico.token)).send({ method: 'EFECTIVO' });

    const detalle = await request(app).get(`/api/payments/${pago.id}`).set(auth(admin.token));
    expect(detalle.body.data.status).toBe('PENDIENTE');
  });

  it.each(['recepcion', 'administrador'])('test_%s_puede_consultar_y_registrar_pagos', async (rol) => {
    const user = rol === 'recepcion' ? recepcion : admin;

    const lista = await request(app).get('/api/payments').set(auth(user.token));
    const detalle = await request(app).get(`/api/payments/${pago.id}`).set(auth(user.token));

    expect(lista.status).toBe(200);
    expect(detalle.status).toBe(200);
  });

  it('test_el_mecanico_no_recibe_el_bloque_de_cobro_en_el_detalle_de_la_orden', async () => {
    const delMecanico = await request(app).get(`/api/orders/${orden.id}`).set(auth(mecanico.token));
    const deRecepcion = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(delMecanico.status).toBe(200);
    expect(delMecanico.body.data).not.toHaveProperty('billing');
    expect(JSON.stringify(delMecanico.body)).not.toContain('checkoutUrl');
    expect(deRecepcion.body.data).toHaveProperty('billing');
  });

  it('test_el_detalle_de_una_orden_entregada_conserva_sus_pagos_en_solo_lectura', async () => {
    await request(app).post(`/api/payments/${pago.id}/cancel`).set(auth(recepcion.token));
    const cobro = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
    await request(app).post(`/api/orders/${orden.id}/status`).set(auth(recepcion.token)).send({ status: 'ENTREGADO' });

    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(cobro.status).toBe(201);
    expect(detalle.body.data.status).toBe('ENTREGADO');
    expect(detalle.body.data.billing.payments.map((p) => p.status)).toEqual(['PAGADO', 'CANCELADO']);
    const intento = await request(app).post(`/api/payments/${cobro.body.data.id}/cancel`).set(auth(admin.token));
    expect(intento.status).toBe(409);
  });
});
