import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createPayableOrder, createPayment, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;

const objetoTicket = {
  id: expect.any(Number),
  folio: expect.stringMatching(/^TK-\d{6}$/),
  orderId: expect.any(Number),
  orderFolio: expect.stringMatching(/^OS-\d{6}$/),
  paymentId: expect.any(Number),
  generatedAt: expect.any(String),
  generatedBy: { id: expect.any(Number), name: expect.any(String) },
};

const contenido = {
  shop: { name: expect.any(String), address: expect.any(String), phone: expect.any(String) },
  customer: { name: expect.any(String), phone: expect.anything() },
  vehicle: { plate: expect.any(String), brand: expect.any(String), model: expect.any(String), year: expect.any(Number), mileage: expect.any(Number) },
  order: { folio: expect.stringMatching(/^OS-\d{6}$/), entryMileage: expect.any(Number), serviceMileage: null },
  services: expect.any(Array),
  parts: expect.any(Array),
  labor: expect.any(Array),
  totals: { services: expect.stringMatching(/^\d+\.\d{2}$/), labor: expect.stringMatching(/^\d+\.\d{2}$/), total: expect.stringMatching(/^\d+\.\d{2}$/) },
  payment: { method: expect.any(String), status: 'PAGADO', paidAt: expect.any(String), reference: null },
  generatedAt: expect.any(String),
};

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'TCT-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
});

describe('POST /api/orders/:id/ticket (contrato)', () => {
  it('test_primera_generacion_responde_201_con_ticket_y_created_true', async () => {
    await createPayment(orden.id, recepcion.id);

    const res = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ ticket: { ...objetoTicket, content: contenido }, created: true });
  });

  it('test_la_segunda_responde_200_con_created_false', async () => {
    await createPayment(orden.id, recepcion.id);
    await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    const res = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data.created).toBe(false);
    expect(res.body.data.ticket).toMatchObject(objetoTicket);
  });

  it('test_sin_pago_pagado_responde_409_con_mensaje_en_espanol', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    expect(res.status).toBe(409);
    expect(res.body.error).toEqual({ code: 'TICKET_REQUIRES_PAYMENT', message: expect.stringContaining('cobrada') });
  });
});

describe('consultas de tickets (contrato)', () => {
  beforeEach(async () => {
    await createPayment(orden.id, recepcion.id);
    await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));
  });

  it('test_get_por_orden_y_por_id_traen_el_ticket_completo', async () => {
    const porOrden = await request(app).get(`/api/orders/${orden.id}/ticket`).set(auth(admin.token));
    const porId = await request(app).get(`/api/tickets/${porOrden.body.data.id}`).set(auth(admin.token));

    expect(porOrden.status).toBe(200);
    expect(porOrden.body.data).toEqual({ ...objetoTicket, content: contenido });
    expect(porId.body.data).toEqual(porOrden.body.data);
  });

  it('test_el_listado_trae_meta_y_omite_el_contenido', async () => {
    const res = await request(app).get('/api/tickets').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data[0]).toEqual({ ...objetoTicket, client: { name: expect.any(String) }, vehicle: { licensePlate: 'TCT-001-A' }, total: '1250.00' });
  });

  it('test_rechaza_parametros_invalidos_con_400_y_exige_rol', async () => {
    expect((await request(app).get('/api/tickets?page=0').set(auth(admin.token))).status).toBe(400);
    expect((await request(app).get('/api/tickets').set(auth(mecanico.token))).status).toBe(403);
    expect((await request(app).get('/api/tickets')).status).toBe(401);
  });
});
