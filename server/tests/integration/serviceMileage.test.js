import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let otroMecanico;
let vehiculo;
let orden;

const registrar = (user, id, serviceMileage) =>
  request(app).put(`/api/orders/${id}/service-mileage`).set(auth(user.token)).send({ serviceMileage });

const kilometrajeDelVehiculo = async () => (await query('SELECT current_mileage FROM vehicles WHERE id = ?', [vehiculo.id]))[0].current_mileage;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'KMS-001-A', currentMileage: 50000 }));
  orden = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 50000 });
});

describe('kilometraje del servicio (US2, FR-004)', () => {
  it('test_acepta_un_kilometraje_mayor_al_de_entrada_y_actualiza_el_del_vehiculo', async () => {
    const res = await registrar(mecanico, orden.id, 50120);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id: orden.id, serviceMileage: 50120, entryMileage: 50000 });
    expect(await kilometrajeDelVehiculo()).toBe(50120);
  });

  it('test_acepta_un_kilometraje_igual_al_de_entrada_sin_bajar_el_del_vehiculo', async () => {
    await query('UPDATE vehicles SET current_mileage = 50300 WHERE id = ?', [vehiculo.id]);

    const res = await registrar(mecanico, orden.id, 50000);

    expect(res.status).toBe(200);
    expect(res.body.data.serviceMileage).toBe(50000);
    expect(await kilometrajeDelVehiculo()).toBe(50300);
  });

  it('test_rechaza_un_kilometraje_menor_al_de_entrada', async () => {
    const res = await registrar(mecanico, orden.id, 49999);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SERVICE_MILEAGE_TOO_LOW');
    expect(await kilometrajeDelVehiculo()).toBe(50000);
  });

  it.each([-1, 2000001, 1.5, '50100', null])('test_rechaza_el_kilometraje_%p_con_400', async (valor) => {
    const res = await registrar(mecanico, orden.id, valor);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_permite_corregirlo_mientras_la_orden_siga_terminada', async () => {
    await registrar(mecanico, orden.id, 50200);

    const res = await registrar(mecanico, orden.id, 50150);

    expect(res.status).toBe(200);
    expect(res.body.data.serviceMileage).toBe(50150);
  });

  it('test_un_vehiculo_sin_kilometraje_previo_acepta_el_valor', async () => {
    await query('UPDATE vehicles SET current_mileage = NULL WHERE id = ?', [vehiculo.id]);

    const res = await registrar(mecanico, orden.id, 50010);

    expect(res.status).toBe(200);
    expect(await kilometrajeDelVehiculo()).toBe(50010);
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])(
    'test_solo_con_la_orden_terminada_no_se_acepta_en_estado_%s',
    async (estado) => {
      const { vehicle } = await createClientWithVehicle({ licensePlate: `KMS-${estado.slice(0, 3)}-B` });
      const abierta = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: estado });

      const res = await registrar(mecanico, abierta.id, 50100);

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_NOT_FINISHED');
    },
  );

  it('test_una_orden_entregada_es_de_solo_lectura', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'KMS-ENT-C' });
    const entregada = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO' });

    const res = await registrar(mecanico, entregada.id, 60000);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
  });

  it('test_un_mecanico_no_asignado_recibe_404', async () => {
    const res = await registrar(otroMecanico, orden.id, 50100);

    expect(res.status).toBe(404);
  });

  it('test_recepcion_recibe_403', async () => {
    const res = await registrar(recepcion, orden.id, 50100);

    expect(res.status).toBe(403);
  });

  it('test_el_administrador_puede_registrarlo', async () => {
    const res = await registrar(admin, orden.id, 50100);

    expect(res.status).toBe(200);
  });

  it('test_el_detalle_de_la_orden_incluye_el_kilometraje_del_servicio', async () => {
    await registrar(mecanico, orden.id, 50100);

    const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(res.body.data.serviceMileage).toBe(50100);
  });

  it('test_una_orden_inexistente_responde_404', async () => {
    const res = await registrar(admin, 999999, 100);

    expect(res.status).toBe(404);
  });
});
