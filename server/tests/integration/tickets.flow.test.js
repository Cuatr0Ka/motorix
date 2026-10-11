import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createLabor,
  createOrderPart,
  createPart,
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
let cliente;
let vehiculo;
let orden;

const generar = (user = recepcion, id = orden.id) => request(app).post(`/api/orders/${id}/ticket`).set(auth(user.token));
const cobrar = (metodo = 'EFECTIVO') => request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: metodo, reference: 'TERM-48213' });

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC', { name: 'Mario Mecánico' });
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'TIC-001-A', brand: 'Nissan', model: 'Versa', year: 2019 }, { name: 'Ana Morales', phone: '5512345678' }));
  orden = await createPayableOrder(vehiculo.id, recepcion.id, mecanico.id);
});

afterAll(() => resetGateway());

describe('generar el ticket (US3, CA-4)', () => {
  it('test_genera_el_ticket_con_folio_unico_orden_pago_y_todos_los_campos', async () => {
    await createOrderPart(orden.id, (await createPart(admin.id, { code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego' })).id, mecanico.id, 2);
    await createLabor(orden.id, { description: 'Revisión de frenos', amount: '100.00' });
    const pago = await cobrar();

    const res = await generar();

    expect(res.status).toBe(201);
    expect(res.body.data.created).toBe(true);
    const { ticket } = res.body.data;
    expect(ticket).toMatchObject({
      folio: expect.stringMatching(/^TK-\d{6}$/),
      orderId: orden.id,
      paymentId: pago.body.data.id,
      generatedBy: { id: recepcion.id },
    });
    expect(ticket.content).toMatchObject({
      shop: { name: expect.any(String), address: expect.any(String), phone: expect.any(String) },
      customer: { name: 'Ana Morales', phone: '5512345678' },
      vehicle: { plate: 'TIC-001-A', brand: 'Nissan', model: 'Versa', year: 2019, mileage: 50000 },
      order: { folio: `OS-${String(orden.id).padStart(6, '0')}`, entryMileage: 50000, serviceMileage: null },
      services: [{ description: 'Cambio de balatas', amount: '850.00' }],
      parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 2 }],
      labor: [
        { description: 'Mano de obra frenos', amount: '400.00' },
        { description: 'Revisión de frenos', amount: '100.00' },
      ],
      totals: { services: '850.00', labor: '500.00', total: '1350.00' },
      payment: { method: 'EFECTIVO', status: 'PAGADO', reference: 'TERM-48213' },
    });
    expect(ticket.content.payment.paidAt).toEqual(expect.any(String));
    expect(ticket.content.generatedAt).toEqual(expect.any(String));
    expect(ticket.content.parts[0]).not.toHaveProperty('amount');
  });

  it('test_usa_los_datos_del_taller_configurados_por_entorno', async () => {
    const anterior = { ...process.env };
    process.env.SHOP_NAME = 'Taller Configurado';
    process.env.SHOP_ADDRESS = 'Av. Siempre Viva 742';
    process.env.SHOP_PHONE = '5598765432';
    try {
      await cobrar();

      const res = await generar();

      expect(res.body.data.ticket.content.shop).toEqual({ name: 'Taller Configurado', address: 'Av. Siempre Viva 742', phone: '5598765432' });
    } finally {
      for (const clave of ['SHOP_NAME', 'SHOP_ADDRESS', 'SHOP_PHONE']) {
        if (anterior[clave] === undefined) delete process.env[clave];
        else process.env[clave] = anterior[clave];
      }
    }
  });

  it('test_funciona_con_un_pago_de_mercado_pago_pagado', async () => {
    await createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'PAGADO', externalPaymentId: '555' });

    const res = await generar(admin);

    expect(res.status).toBe(201);
    expect(res.body.data.ticket.content.payment).toMatchObject({ method: 'MERCADO_PAGO', status: 'PAGADO' });
  });

  it('test_generar_de_nuevo_devuelve_el_ticket_existente_sin_folio_nuevo', async () => {
    await cobrar();
    const primero = await generar();

    const segundo = await generar(admin);

    expect(segundo.status).toBe(200);
    expect(segundo.body.data.created).toBe(false);
    expect(segundo.body.data.ticket.id).toBe(primero.body.data.ticket.id);
    expect(segundo.body.data.ticket.folio).toBe(primero.body.data.ticket.folio);
    expect(await query('SELECT id FROM tickets')).toHaveLength(1);
  });

  it.each([
    ['sin pago', async () => {}],
    ['con un pago pendiente', async () => createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'PENDIENTE', externalReference: 'x' })],
    ['con un pago rechazado', async () => createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'RECHAZADO' })],
    ['con un pago cancelado', async () => createPayment(orden.id, recepcion.id, { method: 'MERCADO_PAGO', status: 'CANCELADO' })],
  ])('test_no_genera_el_ticket_%s', async (_nombre, preparar) => {
    await preparar();

    const res = await generar();

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('TICKET_REQUIRES_PAYMENT');
    expect(await query('SELECT id FROM tickets')).toEqual([]);
  });

  it('test_una_orden_inexistente_responde_404', async () => {
    expect((await generar(recepcion, 999999)).status).toBe(404);
  });
});

describe('el ticket conserva los datos con los que se generó (FR-014, SC-007)', () => {
  it('test_no_cambia_aunque_cambien_servicios_cliente_vehiculo_o_taller', async () => {
    await cobrar();
    const generado = await generar();
    const original = generado.body.data.ticket.content;

    await createService(orden.id, { description: 'Servicio agregado después', amount: '999.00' });
    await query('UPDATE clients SET name = ?, phone = ? WHERE id = ?', ['Nombre Cambiado', '5500000000', cliente.id]);
    await query('UPDATE vehicles SET license_plate = ?, brand = ? WHERE id = ?', ['ZZZ-999-Z', 'Otra marca', vehiculo.id]);
    process.env.SHOP_NAME = 'Taller que cambió de nombre';

    try {
      const consultado = await request(app).get(`/api/tickets/${generado.body.data.ticket.id}`).set(auth(admin.token));
      const porOrden = await request(app).get(`/api/orders/${orden.id}/ticket`).set(auth(admin.token));

      expect(consultado.body.data.content).toEqual(original);
      expect(porOrden.body.data.content).toEqual(original);
      expect(consultado.body.data.content.totals.total).toBe('1250.00');
      expect(consultado.body.data.content.customer.name).toBe('Ana Morales');
      expect(consultado.body.data.content.vehicle.plate).toBe('TIC-001-A');
    } finally {
      delete process.env.SHOP_NAME;
    }
  });

  it('test_una_orden_entregada_conserva_su_ticket', async () => {
    await cobrar();
    await generar();
    await request(app).post(`/api/orders/${orden.id}/status`).set(auth(recepcion.token)).send({ status: 'ENTREGADO' });

    const ticket = await request(app).get(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));
    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(ticket.status).toBe(200);
    expect(detalle.body.data.billing.ticket).toEqual({ id: ticket.body.data.id, folio: ticket.body.data.folio });
  });

  it('test_el_bloque_de_cobro_enlaza_el_ticket_una_vez_generado', async () => {
    await cobrar();
    const antes = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));
    const generado = await generar();
    const despues = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(antes.body.data.billing.ticket).toBeNull();
    expect(despues.body.data.billing.ticket).toEqual({ id: generado.body.data.ticket.id, folio: generado.body.data.ticket.folio });
  });

  it('test_no_existen_operaciones_para_editar_ni_eliminar_tickets', async () => {
    await cobrar();
    const { body } = await generar();
    const id = body.data.ticket.id;

    for (const metodo of ['delete', 'put', 'patch']) {
      const res = await request(app)[metodo](`/api/tickets/${id}`).set(auth(admin.token)).send({});
      expect(res.status).toBe(404);
    }
    for (const metodo of ['delete', 'put', 'patch']) {
      const res = await request(app)[metodo](`/api/orders/${orden.id}/ticket`).set(auth(admin.token)).send({});
      expect(res.status).toBe(404);
    }
    expect(await query('SELECT id FROM tickets')).toHaveLength(1);
  });
});

describe('consulta de tickets y permisos', () => {
  let otra;

  beforeEach(async () => {
    await cobrar();
    await generar();
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'TIC-002-B' }, { name: 'Luis Pérez' });
    otra = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
    await createPayment(otra.id, recepcion.id, { method: 'TARJETA', amount: '1250.00' });
    await generar(recepcion, otra.id);
  });

  const listar = (q = '', user = recepcion) => request(app).get(`/api/tickets${q}`).set(auth(user.token));

  it('test_lista_los_tickets_del_mas_reciente_al_mas_antiguo_sin_el_contenido_completo', async () => {
    const res = await listar();

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 2 });
    expect(res.body.data.map((t) => t.orderId)).toEqual([otra.id, orden.id]);
    expect(res.body.data[0]).toMatchObject({ folio: expect.any(String), orderFolio: expect.any(String), client: { name: 'Luis Pérez' }, vehicle: { licensePlate: 'TIC-002-B' }, total: '1250.00' });
    expect(res.body.data[0]).not.toHaveProperty('content');
  });

  it('test_busca_por_folio_de_ticket_folio_de_orden_cliente_y_placa', async () => {
    const todos = (await listar()).body.data;
    const primero = todos.find((t) => t.orderId === orden.id);

    expect((await listar(`?search=${primero.folio}`)).body.data.map((t) => t.orderId)).toEqual([orden.id]);
    expect((await listar(`?search=OS-${otra.id}`)).body.data.map((t) => t.orderId)).toEqual([otra.id]);
    expect((await listar('?search=ana%20morales')).body.data.map((t) => t.orderId)).toEqual([orden.id]);
    expect((await listar('?search=TIC-002')).body.data.map((t) => t.orderId)).toEqual([otra.id]);
    expect((await listar('?search=nadie')).body.data).toEqual([]);
  });

  it('test_pagina_los_resultados', async () => {
    const res = await listar('?page=2&pageSize=1');

    expect(res.body.data).toHaveLength(1);
    expect(res.body.meta).toEqual({ page: 2, pageSize: 1, total: 2 });
  });

  it('test_el_mecanico_recibe_403_en_todas_las_rutas_de_tickets', async () => {
    const [{ id }] = await query('SELECT id FROM tickets LIMIT 1');
    const rutas = [
      ['get', '/api/tickets'],
      ['get', `/api/tickets/${id}`],
      ['get', `/api/orders/${orden.id}/ticket`],
      ['post', `/api/orders/${orden.id}/ticket`],
    ];

    for (const [metodo, ruta] of rutas) {
      const res = await request(app)[metodo](ruta).set(auth(mecanico.token));
      expect([ruta, res.status]).toEqual([ruta, 403]);
    }
  });

  it('test_sin_sesion_responde_401_y_un_ticket_inexistente_404', async () => {
    expect((await request(app).get('/api/tickets')).status).toBe(401);
    expect((await request(app).get('/api/tickets/999999').set(auth(admin.token))).status).toBe(404);
    expect((await request(app).get('/api/tickets/abc').set(auth(admin.token))).status).toBe(400);
  });

  it('test_una_orden_sin_ticket_responde_404_al_consultarlo', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'TIC-003-C' });
    const sinTicket = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);

    const res = await request(app).get(`/api/orders/${sinTicket.id}/ticket`).set(auth(admin.token));

    expect(res.status).toBe(404);
  });
});
