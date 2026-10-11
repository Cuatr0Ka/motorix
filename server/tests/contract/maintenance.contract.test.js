import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let vehiculo;
let orden;

const objetoMantenimiento = {
  id: expect.any(Number),
  description: expect.any(String),
  status: expect.stringMatching(/^(PENDIENTE|ATENDIDO)$/),
  orderId: expect.any(Number),
  orderFolio: expect.stringMatching(/^OS-\d{6}$/),
  vehicle: expect.objectContaining({ id: expect.any(Number), licensePlate: expect.any(String) }),
};

/** Las claves opcionales del contrato siempre existen y valen null o el tipo indicado. */
function verificaClavesOpcionales(mantenimiento) {
  expect(Object.keys(mantenimiento)).toEqual(expect.arrayContaining(['dueDate', 'dueMileage', 'indicator', 'attendedAt']));
  const { dueDate, dueMileage, attendedAt } = mantenimiento;
  expect(dueDate === null || /^\d{4}-\d{2}-\d{2}$/.test(dueDate)).toBe(true);
  expect(dueMileage === null || Number.isInteger(dueMileage)).toBe(true);
  expect(attendedAt === null || typeof attendedAt === 'string').toBe(true);
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'MCT-001-A', currentMileage: 1000 }));
  orden = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 1000 });
});

describe('PUT /api/orders/:id/service-mileage (contrato)', () => {
  it('test_responde_200_con_el_detalle_de_la_orden', async () => {
    const res = await request(app).put(`/api/orders/${orden.id}/service-mileage`).set(auth(mecanico.token)).send({ serviceMileage: 1100 });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id: orden.id, folio: expect.any(String), status: 'TERMINADO', serviceMileage: 1100, entryMileage: 1000 });
  });

  it('test_exige_sesion_y_cuerpo_valido', async () => {
    const sinSesion = await request(app).put(`/api/orders/${orden.id}/service-mileage`).send({ serviceMileage: 1100 });
    const sinCuerpo = await request(app).put(`/api/orders/${orden.id}/service-mileage`).set(auth(mecanico.token)).send({});

    expect(sinSesion.status).toBe(401);
    expect(sinCuerpo.status).toBe(400);
    expect(sinCuerpo.body.error.details[0].field).toBe('serviceMileage');
  });
});

describe('POST /api/orders/:id/maintenance (contrato)', () => {
  it('test_responde_201_con_el_mantenimiento', async () => {
    const res = await request(app)
      .post(`/api/orders/${orden.id}/maintenance`)
      .set(auth(admin.token))
      .send({ description: 'Cambio de aceite', dueMileage: 5000 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject(objetoMantenimiento);
    verificaClavesOpcionales(res.body.data);
    expect(res.body.data.indicator).toMatch(/^(NORMAL|PROXIMO|VENCIDO)$/);
  });

  it('test_exige_la_descripcion', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/maintenance`).set(auth(mecanico.token)).send({ dueMileage: 5000 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('PATCH /api/maintenance/:id y POST /api/maintenance/:id/attend (contrato)', () => {
  let mantenimiento;

  beforeEach(async () => {
    mantenimiento = await createMaintenance(vehiculo.id, orden.id, mecanico.id, { dueDate: null, dueMileage: 5000 });
  });

  it('test_patch_responde_200_con_el_mantenimiento_actualizado', async () => {
    const res = await request(app).patch(`/api/maintenance/${mantenimiento.id}`).set(auth(mecanico.token)).send({ description: 'Nueva descripción' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ ...objetoMantenimiento, description: 'Nueva descripción' });
  });

  it('test_patch_rechaza_un_cuerpo_vacio_con_400', async () => {
    const res = await request(app).patch(`/api/maintenance/${mantenimiento.id}`).set(auth(mecanico.token)).send({});

    expect(res.status).toBe(400);
  });

  it('test_attend_responde_200_y_luego_409', async () => {
    const primera = await request(app).post(`/api/maintenance/${mantenimiento.id}/attend`).set(auth(admin.token));
    const segunda = await request(app).post(`/api/maintenance/${mantenimiento.id}/attend`).set(auth(admin.token));

    expect(primera.status).toBe(200);
    expect(primera.body.data).toMatchObject({ ...objetoMantenimiento, status: 'ATENDIDO', indicator: null });
    expect(segunda.status).toBe(409);
    expect(segunda.body.error.code).toBe('MAINTENANCE_NOT_EDITABLE');
  });

  it('test_exige_sesion_y_rol', async () => {
    const sinSesion = await request(app).patch(`/api/maintenance/${mantenimiento.id}`).send({ description: 'X Y Z' });
    const recepcionista = await request(app).post(`/api/maintenance/${mantenimiento.id}/attend`).set(auth(recepcion.token));

    expect(sinSesion.status).toBe(401);
    expect(recepcionista.status).toBe(403);
  });
});

describe('GET /api/maintenance (contrato)', () => {
  it('test_responde_200_con_la_lista_el_indicador_el_cliente_y_meta', async () => {
    await createMaintenance(vehiculo.id, orden.id, mecanico.id, { dueDate: null, dueMileage: 5000 });

    const res = await request(app).get('/api/maintenance').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.data[0]).toMatchObject({
      ...objetoMantenimiento,
      indicator: expect.stringMatching(/^(NORMAL|PROXIMO|VENCIDO)$/),
      client: { id: expect.any(Number), name: expect.any(String), phone: expect.any(String) },
      vehicle: { id: vehiculo.id, brand: expect.any(String), model: expect.any(String), licensePlate: 'MCT-001-A', currentMileage: 1000 },
    });
    verificaClavesOpcionales(res.body.data[0]);
  });

  it('test_rechaza_parametros_invalidos_con_400', async () => {
    const res = await request(app).get('/api/maintenance?status=OTRO').set(auth(admin.token));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_el_mecanico_recibe_403_y_sin_sesion_401', async () => {
    expect((await request(app).get('/api/maintenance').set(auth(mecanico.token))).status).toBe(403);
    expect((await request(app).get('/api/maintenance')).status).toBe(401);
  });
});
