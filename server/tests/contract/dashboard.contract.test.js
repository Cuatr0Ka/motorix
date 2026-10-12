import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createPayableOrder, createPayment, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const entero = expect.any(Number);

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('GET /api/dashboard (contrato)', () => {
  it('test_responde_200_con_todos_los_grupos_e_indicadores_numericos', async () => {
    const res = await request(app).get('/api/dashboard').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      generatedAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
      orders: { attendedLast30Days: entero, inRepair: entero, pending: entero, finishedAwaitingDelivery: entero },
      appointments: { upcoming: entero },
      maintenance: { upcoming: entero, overdue: entero },
      inventory: { lowStock: entero, outOfStock: entero },
      payments: { ordersAwaitingPayment: entero, pendingMercadoPago: entero },
      recentActivity: { orderChanges: [], payments: [], inventoryMovements: [] },
      charts: {
        ordersByStatus: [
          { status: 'RECIBIDO', total: 0 },
          { status: 'DIAGNOSTICO', total: 0 },
          { status: 'EN_REPARACION', total: 0 },
          { status: 'ESPERANDO_REFACCION', total: 0 },
          { status: 'TERMINADO', total: 0 },
          { status: 'ENTREGADO', total: 0 },
        ],
        incomeByMonth: Array.from({ length: 6 }, () => ({ month: expect.stringMatching(/^\d{4}-\d{2}$/), total: 0 })),
        incomeByMethod: [
          { method: 'EFECTIVO', total: 0 },
          { method: 'TARJETA', total: 0 },
          { method: 'TRANSFERENCIA', total: 0 },
          { method: 'MERCADO_PAGO', total: 0 },
        ],
      },
    });
  });

  it('test_la_actividad_reciente_tiene_la_forma_del_contrato', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'DCT-001-A' });
    const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
    await createPayment(orden.id, recepcion.id);
    await createPart(admin.id, { stock: 3, minStock: 1 });

    const res = await request(app).get('/api/dashboard').set(auth(admin.token));
    const { orderChanges, payments, inventoryMovements } = res.body.data.recentActivity;

    expect(orderChanges[0]).toEqual({ orderId: orden.id, folio: expect.stringMatching(/^OS-\d{6}$/), toStatus: 'RECIBIDO', changedBy: expect.any(String), changedAt: expect.any(String) });
    expect(payments[0]).toEqual({ id: entero, orderFolio: expect.stringMatching(/^OS-\d{6}$/), amount: '1250.00', method: 'EFECTIVO', status: 'PAGADO', createdAt: expect.any(String) });
    expect(inventoryMovements[0]).toEqual({ id: entero, partCode: expect.any(String), type: 'IN', quantity: 3, createdAt: expect.any(String) });
  });

  it('test_exige_sesion_y_rol_de_administracion', async () => {
    expect((await request(app).get('/api/dashboard')).status).toBe(401);
    expect((await request(app).get('/api/dashboard').set(auth(recepcion.token))).status).toBe(403);
    expect((await request(app).get('/api/dashboard').set(auth(mecanico.token))).status).toBe(403);
  });
});
