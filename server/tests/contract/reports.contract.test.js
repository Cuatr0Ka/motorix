import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createOrder, createPayment, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { DENTRO, PERIODO, fecharPago } from '../helpers/reports.js';

const app = createApp();
let admin;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  const recepcion = await createUserWithToken('RECEPTIONIST');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'CON-001-A' });
  const orden = await createOrder(vehicle.id, recepcion.id, { status: 'TERMINADO' });
  const pago = await createPayment(orden.id, recepcion.id, { amount: '1250.00' });
  await fecharPago(pago.id, DENTRO);
});

describe('contrato de /api/reports', () => {
  it('test_income_tiene_la_forma_del_contrato_con_importes_como_cadenas', async () => {
    const res = await request(app).get('/api/reports/income').query(PERIODO).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body.data).sort()).toEqual(['byDay', 'byMethod', 'from', 'paymentsCount', 'to', 'total']);
    expect(res.body.data.total).toMatch(/^\d+\.\d{2}$/);
    expect(Object.keys(res.body.data.byMethod[0]).sort()).toEqual(['method', 'payments', 'total']);
    expect(Object.keys(res.body.data.byDay[0]).sort()).toEqual(['day', 'payments', 'total']);
  });

  it('test_las_cinco_rutas_responden_con_from_to_e_items_o_totales', async () => {
    for (const ruta of ['services', 'productivity', 'parts', 'rotation']) {
      const res = await request(app).get(`/api/reports/${ruta}`).query(PERIODO).set(auth(admin.token));
      expect(res.status).toBe(200);
      expect(res.body.data).toMatchObject({ from: PERIODO.from, to: PERIODO.to, items: expect.any(Array) });
    }
    const partes = await request(app).get('/api/reports/parts').query(PERIODO).set(auth(admin.token));
    expect(Object.keys(partes.body.data.totals).sort()).toEqual(['cost', 'margin', 'marginPercent', 'noCostLines', 'revenue']);
  });

  it('test_sin_token_401_y_un_formato_desconocido_400', async () => {
    expect((await request(app).get('/api/reports/income').query(PERIODO)).status).toBe(401);
    const res = await request(app).get('/api/reports/income').query({ ...PERIODO, format: 'csv' }).set(auth(admin.token));
    expect(res.status).toBe(400);
  });
});
