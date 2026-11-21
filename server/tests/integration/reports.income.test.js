import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClientWithVehicle, createOrder, createPayment, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { DENTRO, PERIODO, fecharPago, nuevoVehiculo } from '../helpers/reports.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let vehiculo;

const ingresos = (q = PERIODO, token = admin.token) => request(app).get('/api/reports/income').query(q).set(auth(token));

async function pago(importe, metodo, fecha, estado = 'PAGADO') {
  const orden = await createOrder((await nuevoVehiculo()).id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
  const creado = await createPayment(orden.id, recepcion.id, { amount: importe, method: metodo, status: estado });
  if (fecha) await fecharPago(creado.id, fecha);
  return creado;
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'ING-001-A' }));
});

describe('reporte de ingresos (US4, FR-019)', () => {
  it('test_solo_cuentan_los_pagos_pagados_con_paid_at_en_el_rango', async () => {
    await pago('1000.00', 'EFECTIVO', DENTRO);
    await pago('500.50', 'TARJETA', DENTRO);
    await pago('300.00', 'MERCADO_PAGO', DENTRO, 'PENDIENTE');
    await pago('300.00', 'MERCADO_PAGO', DENTRO, 'RECHAZADO');
    await pago('300.00', 'MERCADO_PAGO', DENTRO, 'CANCELADO');
    await pago('999.00', 'EFECTIVO', '2026-09-30 23:59:59'); // fuera
    await pago('999.00', 'EFECTIVO', '2026-11-01 00:00:00'); // fuera

    const res = await ingresos();

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ from: '2026-10-01', to: '2026-10-31', total: '1500.50', paymentsCount: 2 });
  });

  it('test_el_total_es_igual_a_la_suma_por_metodo_y_por_dia', async () => {
    await pago('100.10', 'EFECTIVO', '2026-10-02 09:00:00');
    await pago('200.20', 'EFECTIVO', '2026-10-02 18:00:00');
    await pago('300.30', 'TARJETA', '2026-10-05 12:00:00');

    const { data } = (await ingresos()).body;
    const suma = (filas) => filas.reduce((total, fila) => total + Math.round(Number(fila.total) * 100), 0);

    expect(data.total).toBe('600.60');
    expect(suma(data.byMethod)).toBe(60060);
    expect(suma(data.byDay)).toBe(60060);
    expect(data.byDay).toEqual([
      { day: '2026-10-02', payments: 2, total: '300.30' },
      { day: '2026-10-05', payments: 1, total: '300.30' },
    ]);
    expect(data.byMethod.find((m) => m.method === 'EFECTIVO')).toEqual({ method: 'EFECTIVO', payments: 2, total: '300.30' });
  });

  it('test_un_periodo_sin_pagos_devuelve_ceros_y_listas_vacias', async () => {
    const res = await ingresos();

    expect(res.body.data).toMatchObject({ total: '0.00', paymentsCount: 0, byMethod: [], byDay: [] });
  });

  it('test_los_limites_del_rango_son_exactos_con_inicio_y_fin_incluidos', async () => {
    await pago('10.00', 'EFECTIVO', '2026-10-01 00:00:00');
    await pago('20.00', 'EFECTIVO', '2026-10-02 23:59:59');
    await pago('40.00', 'EFECTIVO', '2026-10-03 00:00:00');
    await pago('80.00', 'EFECTIVO', '2026-09-30 23:59:59');

    const res = await ingresos({ from: '2026-10-01', to: '2026-10-02' });

    expect(res.body.data.total).toBe('30.00');
  });

  it('test_un_rango_invalido_responde_400', async () => {
    for (const q of [
      { from: '2026-10-31', to: '2026-10-01' },
      { from: '2026-01-01', to: '2027-12-31' },
      { from: '2026-02-30', to: '2026-03-01' },
      { from: '2026-10-01' },
      {},
    ]) {
      const res = await ingresos(q);
      expect({ q, estado: res.status }).toEqual({ q, estado: 400 });
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_recepcion_y_mecanico_reciben_403', async () => {
    for (const u of [recepcion, mecanico]) expect((await ingresos(PERIODO, u.token)).status).toBe(403);
  });
});
