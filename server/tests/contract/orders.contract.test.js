import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createAppointment,
  createClientWithVehicle,
  createLabor,
  createOrder,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let cliente;
let vehiculo;

const resumen = {
  id: expect.any(Number),
  folio: expect.stringMatching(/^OS-\d{6}$/),
  status: expect.any(String),
  reportedProblem: expect.any(String),
  entryMileage: expect.any(Number),
  createdAt: expect.any(String),
  client: { id: expect.any(Number), name: expect.any(String) },
  vehicle: expect.objectContaining({ id: expect.any(Number), licensePlate: expect.any(String) }),
};

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ client: cliente, vehicle: vehiculo } = await createClientWithVehicle(
    { licensePlate: 'ORD-001-A', currentMileage: 40000 },
    { name: 'Ana Morales' },
  ));
});

describe('POST /api/orders (contrato)', () => {
  it('test_crea_una_orden_directa_y_devuelve_el_detalle_con_201', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ vehicleId: vehiculo.id, entryMileage: 41000, reportedProblem: 'Ruido al frenar' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      ...resumen,
      status: 'RECIBIDO',
      entryMileage: 41000,
      mechanic: null,
      diagnosis: null,
      observations: null,
      recommendations: null,
      mileageCorrection: false,
      appointment: null,
      services: [],
      labor: [],
      totals: { services: '0.00', labor: '0.00', total: '0.00' },
      allowedTransitions: [],
      deliveredAt: null,
    });
    expect(res.body.data.statusHistory).toEqual([
      { fromStatus: null, toStatus: 'RECIBIDO', changedBy: { id: recepcion.id, name: expect.any(String) }, changedAt: expect.any(String) },
    ]);
  });

  it('test_crea_una_orden_desde_una_cita', async () => {
    const cita = await createAppointment(cliente.id, vehiculo.id, recepcion.id, { reason: 'Revisión de frenos' });

    const res = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ appointmentId: cita.id, entryMileage: 40000 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ reportedProblem: 'Revisión de frenos', appointment: { id: cita.id, status: 'EN_PROCESO' } });
  });

  it('test_rechaza_un_kilometraje_ausente_con_400_y_detalle_del_campo', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set(auth(recepcion.token))
      .send({ vehicleId: vehiculo.id, reportedProblem: 'Ruido' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field)).toContain('entryMileage');
  });

  it('test_sin_token_401_y_el_mecanico_recibe_403', async () => {
    const cuerpo = { vehicleId: vehiculo.id, entryMileage: 41000, reportedProblem: 'x' };
    expect((await request(app).post('/api/orders').send(cuerpo)).status).toBe(401);
    const res = await request(app).post('/api/orders').set(auth(mecanico.token)).send(cuerpo);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});

describe('GET /api/orders y /api/orders/:id (contrato)', () => {
  it('test_lista_los_resumenes_con_metadatos_de_paginacion', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });

    const res = await request(app).get('/api/orders').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({
      ...resumen,
      id: orden.id,
      mechanic: { id: mecanico.id, name: expect.any(String) },
    });
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
  });

  it('test_el_detalle_incluye_servicios_mano_de_obra_y_totales', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { diagnosis: 'Balatas gastadas' });
    await createService(orden.id, { description: 'Cambio de balatas', amount: '850.00' });
    await createLabor(orden.id, { description: 'Mano de obra frenos', amount: '400.50' });

    const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data.diagnosis).toBe('Balatas gastadas');
    expect(res.body.data.services).toEqual([{ id: expect.any(Number), description: 'Cambio de balatas', amount: '850.00' }]);
    expect(res.body.data.labor).toEqual([{ id: expect.any(Number), description: 'Mano de obra frenos', amount: '400.50' }]);
    expect(res.body.data.totals).toEqual({ services: '850.00', labor: '400.50', total: '1250.50' });
  });

  it('test_responde_404_si_la_orden_no_existe_y_400_si_el_id_es_invalido', async () => {
    const noExiste = await request(app).get('/api/orders/999999').set(auth(recepcion.token));
    expect(noExiste.status).toBe(404);
    expect(noExiste.body.error.code).toBe('NOT_FOUND');

    const invalido = await request(app).get('/api/orders/abc').set(auth(recepcion.token));
    expect(invalido.status).toBe(400);
  });

  it('test_rechaza_filtros_invalidos_con_400', async () => {
    const res = await request(app).get('/api/orders?status=INVENTADO').set(auth(recepcion.token));
    expect(res.status).toBe(400);
  });

  it('test_sin_token_responde_401', async () => {
    expect((await request(app).get('/api/orders')).status).toBe(401);
    expect((await request(app).get('/api/orders/1')).status).toBe(401);
  });
});

describe('GET /api/orders para el mecánico (contrato)', () => {
  it('test_lista_solo_las_suyas_con_la_misma_forma_de_resumen', async () => {
    const suya = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico.id });
    const otro = await createClientWithVehicle({ licensePlate: 'ORD-777-Z' });
    await createOrder(otro.vehicle.id, recepcion.id);

    const res = await request(app).get('/api/orders').set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ ...resumen, id: suya.id, mechanic: { id: mecanico.id, name: expect.any(String) } });
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
  });

  it('test_el_detalle_de_una_orden_ajena_responde_404_con_el_error_estandar', async () => {
    const ajena = await createOrder(vehiculo.id, recepcion.id);

    const res = await request(app).get(`/api/orders/${ajena.id}`).set(auth(mecanico.token));

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: { code: 'NOT_FOUND', message: 'La orden no existe.' } });
  });
});
