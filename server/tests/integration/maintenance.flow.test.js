import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
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

const hoyMas = (dias) => {
  const fecha = new Date(Date.now() + dias * 24 * 3600 * 1000);
  const pad = (n) => String(n).padStart(2, '0');
  return `${fecha.getFullYear()}-${pad(fecha.getMonth() + 1)}-${pad(fecha.getDate())}`;
};

const programar = (user, id, cuerpo) => request(app).post(`/api/orders/${id}/maintenance`).set(auth(user.token)).send(cuerpo);
const pendientes = async () => query("SELECT id, status FROM maintenance WHERE vehicle_id = ? ORDER BY id", [vehiculo.id]);

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'MNT-001-A', currentMileage: 50000 }));
  orden = await createFinishedOrder(vehiculo.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 50000 });
});

describe('programar el próximo mantenimiento (US2, CA-2)', () => {
  it('test_programa_por_fecha', async () => {
    const res = await programar(mecanico, orden.id, { description: 'Cambio de aceite', dueDate: hoyMas(180) });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      description: 'Cambio de aceite',
      dueDate: hoyMas(180),
      dueMileage: null,
      status: 'PENDIENTE',
      indicator: 'NORMAL',
      orderId: orden.id,
      vehicle: { id: vehiculo.id, licensePlate: 'MNT-001-A' },
    });
    expect(res.body.data.client).toBeUndefined();
  });

  it('test_programa_por_kilometraje', async () => {
    const res = await programar(mecanico, orden.id, { description: 'Rotación de llantas', dueMileage: 60000 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ dueDate: null, dueMileage: 60000, indicator: 'NORMAL' });
  });

  it('test_programa_por_ambos_y_el_administrador_ve_los_datos_del_cliente', async () => {
    const res = await programar(admin, orden.id, { description: 'Servicio mayor', dueDate: hoyMas(10), dueMileage: 60000 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ dueDate: hoyMas(10), dueMileage: 60000, indicator: 'PROXIMO' });
    expect(res.body.data.client).toMatchObject({ id: expect.any(Number), phone: expect.any(String) });
  });

  it('test_acepta_una_fecha_igual_a_hoy', async () => {
    const res = await programar(mecanico, orden.id, { description: 'Revisión hoy', dueDate: hoyMas(0) });

    expect(res.status).toBe(201);
    expect(res.body.data.indicator).toBe('PROXIMO');
  });

  it('test_rechaza_un_mantenimiento_sin_fecha_ni_kilometraje', async () => {
    const res = await programar(mecanico, orden.id, { description: 'Sin objetivo' });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MAINTENANCE_TARGET_REQUIRED');
  });

  it('test_rechaza_una_fecha_anterior_a_hoy', async () => {
    const res = await programar(mecanico, orden.id, { description: 'Pasado', dueDate: hoyMas(-1) });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MAINTENANCE_DATE_IN_PAST');
  });

  it('test_rechaza_un_kilometraje_menor_o_igual_al_actual', async () => {
    const igual = await programar(mecanico, orden.id, { description: 'Igual', dueMileage: 50000 });
    const menor = await programar(mecanico, orden.id, { description: 'Menor', dueMileage: 49000 });

    expect(igual.status).toBe(422);
    expect(igual.body.error.code).toBe('MAINTENANCE_MILEAGE_TOO_LOW');
    expect(menor.body.error.code).toBe('MAINTENANCE_MILEAGE_TOO_LOW');
  });

  it.each([
    [{ description: 'ab', dueMileage: 60000 }, 'description'],
    [{ description: 'Servicio', dueDate: '2027-02-30' }, 'dueDate'],
    [{ description: 'Servicio', dueDate: 'mañana' }, 'dueDate'],
    [{ description: 'Servicio', dueMileage: -5 }, 'dueMileage'],
    [{ description: 'Servicio', dueMileage: 2500000 }, 'dueMileage'],
    [{ description: 'Servicio', dueMileage: 1.5 }, 'dueMileage'],
  ])('test_rechaza_con_400_el_cuerpo_%j', async (cuerpo, campo) => {
    const res = await programar(mecanico, orden.id, cuerpo);

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });

  it('test_la_orden_entregada_tambien_permite_programar', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'MNT-ENT-B', currentMileage: 100 });
    const entregada = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 100 });

    const res = await programar(mecanico, entregada.id, { description: 'Seguimiento', dueMileage: 5000 });

    expect(res.status).toBe(201);
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])(
    'test_una_orden_en_estado_%s_no_permite_programar',
    async (estado) => {
      const { vehicle } = await createClientWithVehicle({ licensePlate: `MNT-${estado.slice(0, 3)}-C`, currentMileage: 100 });
      const abierta = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: estado });

      const res = await programar(mecanico, abierta.id, { description: 'Pronto', dueMileage: 5000 });

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_NOT_FINISHED');
    },
  );

  it('test_un_mecanico_de_otra_orden_recibe_404_y_recepcion_403', async () => {
    const ajeno = await programar(otroMecanico, orden.id, { description: 'Ajeno', dueMileage: 60000 });
    const recepcionista = await programar(recepcion, orden.id, { description: 'Recepción', dueMileage: 60000 });

    expect(ajeno.status).toBe(404);
    expect(recepcionista.status).toBe(403);
    expect(await pendientes()).toEqual([]);
  });

  it('test_un_nuevo_mantenimiento_deja_al_anterior_como_atendido', async () => {
    const primero = await programar(mecanico, orden.id, { description: 'Primero', dueMileage: 60000 });
    const segundo = await programar(mecanico, orden.id, { description: 'Segundo', dueMileage: 70000 });

    expect(segundo.status).toBe(201);
    const filas = await pendientes();
    expect(filas).toEqual([
      { id: primero.body.data.id, status: 'ATENDIDO' },
      { id: segundo.body.data.id, status: 'PENDIENTE' },
    ]);
  });

  it('test_dos_programaciones_simultaneas_dejan_un_solo_pendiente', async () => {
    const [a, b] = await Promise.all([
      programar(mecanico, orden.id, { description: 'Uno', dueMileage: 60000 }),
      programar(admin, orden.id, { description: 'Dos', dueMileage: 70000 }),
    ]);

    expect([a.status, b.status]).toEqual([201, 201]);
    const filas = await pendientes();
    expect(filas).toHaveLength(2);
    expect(filas.filter((f) => f.status === 'PENDIENTE')).toHaveLength(1);
  });

  it('test_el_mantenimiento_aparece_en_el_detalle_de_la_orden_y_en_el_historial', async () => {
    await programar(mecanico, orden.id, { description: 'Cambio de aceite', dueMileage: 60000 });

    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(mecanico.token));
    const historial = await request(app).get(`/api/vehicles/${vehiculo.id}/history`).set(auth(mecanico.token));

    expect(detalle.body.data.maintenance).toMatchObject({ description: 'Cambio de aceite', status: 'PENDIENTE', indicator: 'NORMAL' });
    expect(historial.body.data.entries[0].maintenance).toMatchObject({ description: 'Cambio de aceite' });
    expect(historial.body.data.pendingMaintenance).toMatchObject({ description: 'Cambio de aceite' });
  });
});

describe('editar y atender un mantenimiento', () => {
  let mantenimiento;

  beforeEach(async () => {
    mantenimiento = await createMaintenance(vehiculo.id, orden.id, mecanico.id, {
      description: 'Cambio de aceite',
      dueDate: null,
      dueMileage: 60000,
    });
  });

  const editar = (user, cuerpo, id = mantenimiento.id) => request(app).patch(`/api/maintenance/${id}`).set(auth(user.token)).send(cuerpo);
  const atender = (user, id = mantenimiento.id) => request(app).post(`/api/maintenance/${id}/attend`).set(auth(user.token));

  it('test_edita_la_descripcion_y_el_kilometraje', async () => {
    const res = await editar(mecanico, { description: 'Cambio de aceite sintético', dueMileage: 65000 });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ description: 'Cambio de aceite sintético', dueMileage: 65000 });
  });

  it('test_agrega_una_fecha_y_conserva_el_kilometraje', async () => {
    const res = await editar(admin, { dueDate: hoyMas(90) });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ dueDate: hoyMas(90), dueMileage: 60000 });
  });

  it('test_no_permite_quitar_ambos_objetivos', async () => {
    const res = await editar(mecanico, { dueMileage: null });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MAINTENANCE_TARGET_REQUIRED');
  });

  it('test_valida_solo_los_objetivos_que_cambian', async () => {
    await query('UPDATE vehicles SET current_mileage = 61000 WHERE id = ?', [vehiculo.id]);

    const descripcion = await editar(mecanico, { description: 'Vencido pero editable' });
    const kilometraje = await editar(mecanico, { dueMileage: 60500 });

    expect(descripcion.status).toBe(200);
    expect(descripcion.body.data.indicator).toBe('VENCIDO');
    expect(kilometraje.status).toBe(422);
    expect(kilometraje.body.error.code).toBe('MAINTENANCE_MILEAGE_TOO_LOW');
  });

  it('test_marca_como_atendido_y_ya_no_se_edita', async () => {
    const res = await atender(mecanico);
    const edicion = await editar(mecanico, { description: 'Otro' });
    const otraVez = await atender(admin);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ status: 'ATENDIDO', indicator: null });
    expect(res.body.data.attendedAt).toEqual(expect.any(String));
    expect(edicion.status).toBe(409);
    expect(edicion.body.error.code).toBe('MAINTENANCE_NOT_EDITABLE');
    expect(otraVez.body.error.code).toBe('MAINTENANCE_NOT_EDITABLE');
  });

  it('test_un_mecanico_de_otra_orden_recibe_404_y_recepcion_403', async () => {
    expect((await editar(otroMecanico, { description: 'Ajeno' })).status).toBe(404);
    expect((await atender(otroMecanico)).status).toBe(404);
    expect((await editar(recepcion, { description: 'Recepción' })).status).toBe(403);
    expect((await atender(recepcion)).status).toBe(403);
  });

  it('test_un_mantenimiento_inexistente_responde_404_y_no_existe_delete', async () => {
    expect((await editar(admin, { description: 'Nada' }, 999999)).status).toBe(404);
    const borrar = await request(app).delete(`/api/maintenance/${mantenimiento.id}`).set(auth(admin.token));
    expect(borrar.status).toBe(404);
  });

  it('test_el_atendido_sigue_visible_en_el_historial_del_vehiculo', async () => {
    await atender(mecanico);

    const historial = await request(app).get(`/api/vehicles/${vehiculo.id}/history`).set(auth(recepcion.token));

    expect(historial.body.data.pendingMaintenance).toBeNull();
    expect(historial.body.data.entries[0].maintenance).toMatchObject({ status: 'ATENDIDO', indicator: null });
  });
});
