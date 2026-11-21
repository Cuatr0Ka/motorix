import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createOrder,
  createOrderPart,
  createPart,
  createPayableOrder,
  createPayment,
  createService,
  createTicket,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;
let parte;

const cobrar = (metodo = 'EFECTIVO') => request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: metodo });
const generar = (id = orden.id) => request(app).post(`/api/orders/${id}/ticket`).set(auth(recepcion.token));
const consultar = (id = orden.id) => request(app).get(`/api/orders/${id}/ticket`).set(auth(recepcion.token));
const cambiarPrecio = (precio) => request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ salePrice: precio });

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'TK2-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  parte = await createPart(admin.id, { code: 'TK2-REF', name: 'Balatas delanteras', unit: 'juego', stock: 10, salePrice: 180 });
});

afterAll(() => resetGateway());

describe('ticket nuevo (formato versión 2)', () => {
  it('test_trae_el_formato_version_2_las_refacciones_con_precio_e_importe_y_los_tres_subtotales', async () => {
    await createOrderPart(orden.id, parte.id, mecanico.id, 2, '180.00');
    const pago = await cobrar();

    const res = await generar();

    expect(res.status).toBe(201);
    const { content } = res.body.data.ticket;
    expect(content.formatVersion).toBe(2);
    expect(content.parts).toEqual([
      { code: 'TK2-REF', name: 'Balatas delanteras', unit: 'juego', quantity: 2, unitPrice: '180.00', amount: '360.00' },
    ]);
    expect(content.totals).toEqual({ services: '850.00', labor: '400.00', parts: '360.00', total: '1610.00' });
    expect(content.totals.total).toBe(pago.body.data.amount);
  });

  it('test_las_lineas_anteriores_a_los_precios_aparecen_en_cero_y_no_suman', async () => {
    await createOrderPart(orden.id, parte.id, mecanico.id, 3);
    await cobrar();

    const { content } = (await generar()).body.data.ticket;

    expect(content.parts[0]).toMatchObject({ quantity: 3, unitPrice: '0.00', amount: '0.00' });
    expect(content.totals).toEqual({ services: '850.00', labor: '400.00', parts: '0.00', total: '1250.00' });
  });

  it('test_una_orden_con_solo_refacciones_genera_su_ticket_con_ese_total', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'TK2-002-A' });
    const soloPiezas = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
    await createOrderPart(soloPiezas.id, parte.id, mecanico.id, 1, '180.00');
    const pago = await request(app).post(`/api/orders/${soloPiezas.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });

    const { content } = (await generar(soloPiezas.id)).body.data.ticket;

    expect(pago.status).toBe(201);
    expect(content.totals).toEqual({ services: '0.00', labor: '0.00', parts: '180.00', total: '180.00' });
  });

  it('test_cambiar_el_precio_de_una_refaccion_despues_de_generar_el_ticket_no_altera_su_contenido', async () => {
    await createOrderPart(orden.id, parte.id, mecanico.id, 2, '180.00');
    await cobrar();
    const generado = (await generar()).body.data.ticket;

    const cambio = await cambiarPrecio('999.00');
    const consultado = (await consultar()).body.data;

    expect(cambio.status).toBe(200);
    expect(consultado.content).toEqual(generado.content);
    expect(consultado.content.parts[0].unitPrice).toBe('180.00');
  });

  it('test_si_los_servicios_cambian_despues_del_pago_el_total_del_ticket_sigue_siendo_el_importe_del_pago', async () => {
    // Comportamiento del Sprint 4 que se documenta y no se corrige aquí: los subtotales reflejan las líneas actuales.
    await createOrderPart(orden.id, parte.id, mecanico.id, 2, '180.00');
    const pago = await cobrar();
    await createService(orden.id, { description: 'Servicio agregado después del pago', amount: '100.00' });

    const { content } = (await generar()).body.data.ticket;

    expect(content.totals.total).toBe(pago.body.data.amount);
    expect(content.totals.total).toBe('1610.00');
    expect(content.totals.services).toBe('950.00');
    expect(content.totals.parts).toBe('360.00');
  });

  it('test_el_ticket_no_incluye_el_precio_de_compra_de_la_refaccion', async () => {
    const conCompra = await createPart(admin.id, { code: 'TK2-COS', name: 'Con costo', stock: 5, purchasePrice: 77, salePrice: 150 });
    await createOrderPart(orden.id, conCompra.id, mecanico.id, 1, '150.00');
    await cobrar();

    const texto = JSON.stringify((await generar()).body.data.ticket);

    expect(texto).not.toMatch(/purchase|compra|77\.00/i);
  });
});

describe('ticket anterior al sprint (formato versión 1)', () => {
  const contenidoAnterior = () => ({
    shop: { name: 'Motorix Taller Mecánico', address: '', phone: '' },
    customer: { name: 'Ana Morales', phone: '5512345678' },
    vehicle: { plate: 'TK2-001-A', brand: 'Nissan', model: 'Versa', year: 2019, mileage: 50000 },
    order: { folio: `OS-${String(orden.id).padStart(6, '0')}`, entryMileage: 50000, serviceMileage: null },
    services: [{ description: 'Cambio de balatas', amount: '850.00' }],
    parts: [{ code: 'TK2-REF', name: 'Balatas delanteras', unit: 'juego', quantity: 2 }],
    labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
    totals: { services: '850.00', labor: '400.00', total: '1250.00' },
    payment: { method: 'EFECTIVO', status: 'PAGADO', paidAt: '2026-10-11T15:00:00.000Z', reference: null },
    generatedAt: '2026-10-11T15:10:00.000Z',
  });

  it('test_se_devuelve_tal_como_se_emitio_sin_formato_ni_precios', async () => {
    const pago = await createPayment(orden.id, recepcion.id);
    const original = contenidoAnterior();
    await createTicket(orden.id, pago.id, recepcion.id, { content: original });

    const porOrden = await consultar();

    expect(porOrden.status).toBe(200);
    expect(porOrden.body.data.content).toEqual(original);
    expect(porOrden.body.data.content).not.toHaveProperty('formatVersion');
    expect(porOrden.body.data.content.parts[0]).not.toHaveProperty('unitPrice');
    expect(porOrden.body.data.content.totals).not.toHaveProperty('parts');
  });

  it('test_generar_de_nuevo_devuelve_el_ticket_anterior_sin_convertirlo', async () => {
    const pago = await createPayment(orden.id, recepcion.id);
    const original = contenidoAnterior();
    await createTicket(orden.id, pago.id, recepcion.id, { content: original });

    const res = await generar();

    expect(res.status).toBe(200);
    expect(res.body.data.created).toBe(false);
    expect(res.body.data.ticket.content).toEqual(original);
  });

  it('test_un_ticket_anterior_y_uno_nuevo_conviven_en_el_listado_cada_uno_con_su_formato', async () => {
    const pagoViejo = await createPayment(orden.id, recepcion.id);
    await createTicket(orden.id, pagoViejo.id, recepcion.id, { content: contenidoAnterior() });
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'TK2-004-A' });
    const ordenNueva = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
    await createOrderPart(ordenNueva.id, parte.id, mecanico.id, 1, '180.00');
    await request(app).post(`/api/orders/${ordenNueva.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
    await generar(ordenNueva.id);

    const nuevo = (await consultar(ordenNueva.id)).body.data;
    const viejo = (await consultar()).body.data;
    const listado = await request(app).get('/api/tickets').set(auth(recepcion.token));

    expect(nuevo.content.formatVersion).toBe(2);
    expect(viejo.content).not.toHaveProperty('formatVersion');
    expect(listado.status).toBe(200);
    expect(listado.body.data).toHaveLength(2);
  });
});
