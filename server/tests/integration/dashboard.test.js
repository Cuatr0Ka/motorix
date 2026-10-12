import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createAppointment,
  createClientWithVehicle,
  createMaintenance,
  createOrder,
  createPart,
  createPayableOrder,
  createPayment,
  createService,
  createUserWithToken,
  hoursFromNow,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let seq = 0;

const tablero = () => request(app).get('/api/dashboard').set(auth(admin.token));
const total = async (url) => (await request(app).get(url).set(auth(admin.token))).body.meta.total;

async function nuevoVehiculo(extra = {}) {
  seq += 1;
  return createClientWithVehicle({ licensePlate: `DSH-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000, ...extra });
}

async function ordenEn(estado, { entregadaHaceDias } = {}) {
  const { vehicle } = await nuevoVehiculo();
  const orden = estado === 'TERMINADO' ? await createPayableOrder(vehicle.id, recepcion.id, mecanico.id) : await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: estado });
  if (estado === 'ENTREGADO') {
    await createService(orden.id);
    await query('UPDATE service_orders SET delivered_at = DATE_SUB(NOW(), INTERVAL ? DAY) WHERE id = ?', [entregadaHaceDias ?? 1, orden.id]);
  }
  return { orden, vehicle };
}

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

afterAll(() => resetGateway());

describe('panel de control (US4, CA-6)', () => {
  it('test_un_taller_sin_datos_devuelve_ceros_y_listas_vacias', async () => {
    const res = await tablero();

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      generatedAt: expect.any(String),
      orders: { attendedLast30Days: 0, inRepair: 0, pending: 0, finishedAwaitingDelivery: 0 },
      appointments: { upcoming: 0 },
      maintenance: { upcoming: 0, overdue: 0 },
      inventory: { lowStock: 0, outOfStock: 0 },
      payments: { ordersAwaitingPayment: 0, pendingMercadoPago: 0 },
      recentActivity: { orderChanges: [], payments: [], inventoryMovements: [] },
    });
  });

  describe('con un escenario de datos conocido', () => {
    let terminadaCobrada;
    let terminadaSinCobrar;

    beforeEach(async () => {
      await ordenEn('RECIBIDO');
      await ordenEn('DIAGNOSTICO');
      await ordenEn('EN_REPARACION');
      await ordenEn('ESPERANDO_REFACCION');
      terminadaCobrada = (await ordenEn('TERMINADO')).orden;
      terminadaSinCobrar = (await ordenEn('TERMINADO')).orden;
      await createPayment(terminadaCobrada.id, recepcion.id);
      // Entregadas: dos vehículos distintos en 30 días, un vehículo con dos entregas en la ventana y una fuera.
      await ordenEn('ENTREGADO', { entregadaHaceDias: 3 });
      await ordenEn('ENTREGADO', { entregadaHaceDias: 29 });
      const repetido = await ordenEn('ENTREGADO', { entregadaHaceDias: 5 });
      const segunda = await createOrder(repetido.vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'ENTREGADO' });
      await query('UPDATE service_orders SET delivered_at = DATE_SUB(NOW(), INTERVAL 10 DAY) WHERE id = ?', [segunda.id]);
      await ordenEn('ENTREGADO', { entregadaHaceDias: 40 });
    });

    it('test_cada_indicador_de_ordenes_es_el_esperado', async () => {
      const res = await tablero();

      expect(res.body.data.orders).toEqual({
        attendedLast30Days: 3,
        inRepair: 2,
        pending: 4,
        finishedAwaitingDelivery: 2,
      });
      expect(res.body.data.payments.ordersAwaitingPayment).toBe(1);
    });

    it('test_los_indicadores_de_ordenes_coinciden_con_los_listados', async () => {
      const { body } = await tablero();

      const enReparacion = (await total('/api/orders?status=EN_REPARACION')) + (await total('/api/orders?status=ESPERANDO_REFACCION'));
      const pendientes = enReparacion + (await total('/api/orders?status=RECIBIDO')) + (await total('/api/orders?status=DIAGNOSTICO'));
      const terminadas = await total('/api/orders?status=TERMINADO');

      expect(body.data.orders.inRepair).toBe(enReparacion);
      expect(body.data.orders.pending).toBe(pendientes);
      expect(body.data.orders.finishedAwaitingDelivery).toBe(terminadas);

      // Las terminadas sin cobrar son las que su bloque de cobro no marca como Pagado.
      const terminadasLista = (await request(app).get('/api/orders?status=TERMINADO').set(auth(admin.token))).body.data;
      let sinCobrar = 0;
      for (const orden of terminadasLista) {
        const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(admin.token));
        if (detalle.body.data.billing.collectionStatus !== 'PAGADO') sinCobrar += 1;
      }
      expect(body.data.payments.ordersAwaitingPayment).toBe(sinCobrar);
      expect(terminadaSinCobrar.id).toBeDefined();
    });
  });

  it('test_las_citas_proximas_solo_cuentan_pendientes_y_confirmadas_dentro_de_siete_dias', async () => {
    const citas = [
      ['PENDIENTE', 48],
      ['CONFIRMADA', 24 * 6],
      ['PENDIENTE', 24 * 10],
      ['CANCELADA', 24],
      ['COMPLETADA', 30],
      ['EN_PROCESO', 36],
    ];
    for (const [estado, horas] of citas) {
      const { client, vehicle } = await nuevoVehiculo();
      await createAppointment(client.id, vehicle.id, recepcion.id, { status: estado, scheduledAt: hoyHora(horas) });
    }
    const { client, vehicle } = await nuevoVehiculo();
    await createAppointment(client.id, vehicle.id, recepcion.id, { status: 'PENDIENTE', scheduledAt: hoyHora(-5) });

    const { body } = await tablero();
    const desde = encodeURIComponent(new Date().toISOString());
    const hasta = encodeURIComponent(new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString());
    const enLista = (await total(`/api/appointments?status=PENDIENTE&from=${desde}&to=${hasta}`)) + (await total(`/api/appointments?status=CONFIRMADA&from=${desde}&to=${hasta}`));

    expect(body.data.appointments.upcoming).toBe(2);
    expect(body.data.appointments.upcoming).toBe(enLista);
  });

  it('test_los_mantenimientos_y_el_inventario_coinciden_con_sus_listados', async () => {
    const dia = 24 * 3600 * 1000;
    const casos = [
      { dueDate: new Date(Date.now() - 3 * dia), dueMileage: null },
      { dueDate: null, dueMileage: 1000 },
      { dueDate: new Date(Date.now() + 10 * dia), dueMileage: null },
      { dueDate: new Date(Date.now() + 300 * dia), dueMileage: null },
    ];
    for (const caso of casos) {
      const { vehicle } = await nuevoVehiculo();
      const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
      await createMaintenance(vehicle.id, orden.id, mecanico.id, caso);
    }
    await createPart(admin.id, { stock: 1, minStock: 5 });
    await createPart(admin.id, { stock: 0, minStock: 2 });
    await createPart(admin.id, { stock: 50, minStock: 2 });

    const { body } = await tablero();
    const alertas = (await request(app).get('/api/parts/alerts').set(auth(admin.token))).body.data;

    expect(body.data.maintenance).toEqual({
      upcoming: await total('/api/maintenance?indicator=PROXIMO'),
      overdue: await total('/api/maintenance?indicator=VENCIDO'),
    });
    expect(body.data.maintenance).toEqual({ upcoming: 1, overdue: 2 });
    expect(body.data.inventory).toEqual({ lowStock: alertas.count, outOfStock: alertas.outOfStock });
    expect(body.data.inventory).toEqual({ lowStock: 2, outOfStock: 1 });
  });

  it('test_los_pagos_pendientes_de_mercado_pago_coinciden_con_el_listado', async () => {
    for (const estado of ['PENDIENTE', 'PENDIENTE', 'PAGADO', 'RECHAZADO']) {
      const { vehicle } = await nuevoVehiculo();
      const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
      await createPayment(orden.id, recepcion.id, estado === 'PAGADO' ? {} : { method: 'MERCADO_PAGO', status: estado, externalReference: 'x' });
    }

    const { body } = await tablero();

    expect(body.data.payments.pendingMercadoPago).toBe(2);
    expect(body.data.payments.pendingMercadoPago).toBe(await total('/api/payments?status=PENDIENTE'));
  });

  it('test_los_indicadores_reflejan_los_cambios_sin_pasos_adicionales', async () => {
    const { orden } = await ordenEn('EN_REPARACION');
    const antes = (await tablero()).body.data;

    await request(app).post(`/api/orders/${orden.id}/status`).set(auth(mecanico.token)).send({ status: 'TERMINADO' });
    await createService(orden.id);
    const terminada = (await tablero()).body.data;
    await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
    const cobrada = (await tablero()).body.data;

    expect([antes.orders.inRepair, antes.orders.finishedAwaitingDelivery, antes.payments.ordersAwaitingPayment]).toEqual([1, 0, 0]);
    expect([terminada.orders.inRepair, terminada.orders.finishedAwaitingDelivery, terminada.payments.ordersAwaitingPayment]).toEqual([0, 1, 1]);
    expect([cobrada.orders.finishedAwaitingDelivery, cobrada.payments.ordersAwaitingPayment]).toEqual([1, 0]);
  });
});

describe('actividad reciente', () => {
  it('test_cada_lista_trae_como_maximo_cinco_elementos_del_mas_reciente_al_mas_antiguo', async () => {
    const ordenes = [];
    for (let i = 0; i < 7; i += 1) {
      const { vehicle } = await nuevoVehiculo();
      ordenes.push(await createPayableOrder(vehicle.id, recepcion.id, mecanico.id));
    }
    for (const orden of ordenes) await createPayment(orden.id, recepcion.id);
    const parte = await createPart(admin.id, { stock: 20, minStock: 1 });
    for (let i = 0; i < 6; i += 1) {
      await request(app).post(`/api/parts/${parte.id}/movements`).set(auth(admin.token)).send({ type: 'IN', quantity: i + 1 });
    }

    const { body } = await tablero();
    const actividad = body.data.recentActivity;

    expect(actividad.orderChanges).toHaveLength(5);
    expect(actividad.payments).toHaveLength(5);
    expect(actividad.inventoryMovements).toHaveLength(5);
    expect(actividad.payments.map((p) => p.orderFolio)).toEqual(ordenes.slice(2).reverse().map((o) => `OS-${String(o.id).padStart(6, '0')}`));
    expect(actividad.inventoryMovements.map((m) => m.quantity)).toEqual([6, 5, 4, 3, 2]);
    expect(actividad.orderChanges[0]).toMatchObject({ orderId: ordenes[6].id, folio: expect.stringMatching(/^OS-\d{6}$/), toStatus: 'RECIBIDO', changedBy: expect.any(String) });
    expect(actividad.payments[0]).toMatchObject({ id: expect.any(Number), amount: '1250.00', method: 'EFECTIVO', status: 'PAGADO', createdAt: expect.any(String) });
    expect(actividad.inventoryMovements[0]).toMatchObject({ partCode: parte.code, type: 'IN' });
  });
});

describe('permisos del panel (FR-021, SC-008)', () => {
  it('test_recepcion_y_mecanico_reciben_403_y_sin_sesion_401', async () => {
    const recepcionRes = await request(app).get('/api/dashboard').set(auth(recepcion.token));
    const mecanicoRes = await request(app).get('/api/dashboard').set(auth(mecanico.token));
    const sinSesion = await request(app).get('/api/dashboard');

    expect(recepcionRes.status).toBe(403);
    expect(recepcionRes.body.error.code).toBe('FORBIDDEN');
    expect(mecanicoRes.status).toBe(403);
    expect(sinSesion.status).toBe(401);
  });

  it('test_el_panel_no_acepta_otros_metodos', async () => {
    for (const metodo of ['post', 'put', 'patch', 'delete']) {
      const res = await request(app)[metodo]('/api/dashboard').set(auth(admin.token)).send({});
      expect(res.status).toBe(404);
    }
  });
});

/** Fecha futura (o pasada con horas negativas) con segundos en cero, sin choques de horario. */
function hoyHora(horas) {
  const fecha = hoursFromNow(horas);
  fecha.setMilliseconds(0);
  return fecha;
}

describe('datos de las gráficas', () => {
  it('test_las_graficas_cuentan_ordenes_por_estado_e_ingresos_pagados_por_mes_y_metodo', async () => {
    await ordenEn('RECIBIDO');
    await ordenEn('EN_REPARACION');
    await ordenEn('EN_REPARACION');
    const { orden } = await ordenEn('TERMINADO');
    await createPayment(orden.id, recepcion.id, { amount: '1250.00', method: 'TARJETA' });

    const { charts } = (await tablero()).body.data;

    const porEstado = Object.fromEntries(charts.ordersByStatus.map((e) => [e.status, e.total]));
    expect(porEstado).toEqual({ RECIBIDO: 1, DIAGNOSTICO: 0, EN_REPARACION: 2, ESPERANDO_REFACCION: 0, TERMINADO: 1, ENTREGADO: 0 });
    expect(charts.incomeByMonth).toHaveLength(6);
    expect(charts.incomeByMonth.at(-1).total).toBe(1250);
    expect(charts.incomeByMonth.slice(0, -1).every((m) => m.total === 0)).toBe(true);
    expect(charts.incomeByMethod.find((m) => m.method === 'TARJETA').total).toBe(1250);
    expect(charts.incomeByMethod.find((m) => m.method === 'EFECTIVO').total).toBe(0);
  });

  it('test_los_pagos_no_pagados_no_suman_en_los_ingresos', async () => {
    const { orden } = await ordenEn('TERMINADO');
    await createPayment(orden.id, recepcion.id, { amount: '900.00', status: 'PENDIENTE', method: 'MERCADO_PAGO' });

    const { charts } = (await tablero()).body.data;

    expect(charts.incomeByMonth.every((m) => m.total === 0)).toBe(true);
    expect(charts.incomeByMethod.every((m) => m.total === 0)).toBe(true);
  });
});
