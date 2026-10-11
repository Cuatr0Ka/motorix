import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createLabor,
  createMaintenance,
  createOrderPart,
  createPart,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let vehiculo;
let orden;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC', { name: 'Mario Mecánico' });
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'HIS-001-A', currentMileage: 52000 }));
  orden = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 51000 });
  await createLabor(orden.id);
  const parte = await createPart(admin.id, { code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego' });
  await createOrderPart(orden.id, parte.id, mecanico.id, 1);
  await createMaintenance(vehiculo.id, orden.id, mecanico.id, { description: 'Cambio de aceite', dueMileage: 60000 });
});

describe('GET /api/vehicles/:id/history (contrato)', () => {
  it('test_devuelve_la_forma_del_contrato_con_vehiculo_entradas_y_meta', async () => {
    const res = await request(app).get(`/api/vehicles/${vehiculo.id}/history`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data.vehicle).toEqual({
      id: vehiculo.id,
      brand: 'Nissan',
      model: 'Versa',
      year: 2020,
      licensePlate: 'HIS-001-A',
      currentMileage: 52000,
    });
    expect(res.body.data.entries).toHaveLength(1);
    expect(res.body.data.entries[0]).toMatchObject({
      orderId: orden.id,
      folio: expect.stringMatching(/^OS-\d{6}$/),
      status: 'ENTREGADO',
      mileage: 51000,
      reportedProblem: 'Ruido al frenar',
      diagnosis: 'Diagnóstico de prueba',
      services: [{ description: 'Cambio de balatas', amount: '850.00' }],
      labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
      parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 1 }],
      mechanic: { id: mecanico.id, name: 'Mario Mecánico' },
      maintenance: { description: 'Cambio de aceite', dueMileage: 60000, status: 'PENDIENTE', indicator: 'NORMAL' },
    });
    expect(res.body.data.entries[0].serviceDate).toEqual(expect.any(String));
    expect(res.body.data.pendingMaintenance).toMatchObject({ description: 'Cambio de aceite', indicator: 'NORMAL' });
  });

  it('test_responde_404_si_el_vehiculo_no_existe', async () => {
    const res = await request(app).get('/api/vehicles/999999/history').set(auth(admin.token));

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_responde_401_sin_sesion', async () => {
    const res = await request(app).get(`/api/vehicles/${vehiculo.id}/history`);

    expect(res.status).toBe(401);
  });

  it('test_rechaza_una_paginacion_invalida_con_400', async () => {
    const res = await request(app).get(`/api/vehicles/${vehiculo.id}/history?page=0`).set(auth(admin.token));

    expect(res.status).toBe(400);
  });

  it.each([
    ['administrador', () => admin],
    ['recepcionista', () => recepcion],
    ['mecanico', () => mecanico],
  ])('test_el_rol_%s_puede_consultar_el_historial', async (_, quien) => {
    const res = await request(app).get(`/api/vehicles/${vehiculo.id}/history`).set(auth(quien().token));

    expect(res.status).toBe(200);
  });
});
