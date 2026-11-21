import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createService,
  createServiceType,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;

const crear = (cuerpo, token = admin.token) => request(app).post('/api/service-types').set(auth(token)).send(cuerpo);
const lineaServicio = (cuerpo, token = mecanico.token) =>
  request(app).post(`/api/orders/${orden.id}/services`).set(auth(token)).send({ description: 'Cambio de aceite', amount: 500, ...cuerpo });

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle();
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
});

describe('catálogo de tipos de servicio (US3, FR-005 y FR-006)', () => {
  it('test_crea_edita_y_desactiva_un_tipo_sin_borrarlo', async () => {
    const alta = await crear({ name: 'Afinación mayor', intervalDays: 365, intervalKm: 10000 });
    expect(alta.status).toBe(201);
    expect(alta.body.data).toMatchObject({ name: 'Afinación mayor', intervalDays: 365, intervalKm: 10000, active: true, inUse: 0 });

    const edicion = await request(app).patch(`/api/service-types/${alta.body.data.id}`).set(auth(admin.token)).send({ intervalKm: null });
    expect(edicion.status).toBe(200);
    expect(edicion.body.data.intervalKm).toBeNull();

    const baja = await request(app).patch(`/api/service-types/${alta.body.data.id}`).set(auth(admin.token)).send({ active: false });
    expect(baja.body.data.active).toBe(false);

    const borrar = await request(app).delete(`/api/service-types/${alta.body.data.id}`).set(auth(admin.token));
    expect(borrar.status).toBe(404);
    const lista = await request(app).get('/api/service-types').set(auth(admin.token));
    expect(lista.body.meta.total).toBe(1);
  });

  it('test_el_nombre_es_unico_sin_distinguir_mayusculas', async () => {
    await crear({ name: 'Cambio de aceite', intervalDays: 180 });
    const repetido = await crear({ name: 'CAMBIO DE ACEITE', intervalKm: 5000 });

    expect(repetido.status).toBe(409);
    expect(repetido.body.error.code).toBe('SERVICE_TYPE_DUPLICATE');
  });

  it('test_un_tipo_sin_intervalos_se_rechaza_y_los_valores_invalidos_tambien', async () => {
    const sinIntervalo = await crear({ name: 'Sin intervalo' });
    expect(sinIntervalo.status).toBe(422);
    expect(sinIntervalo.body.error.code).toBe('SERVICE_TYPE_INTERVAL_REQUIRED');

    for (const cuerpo of [
      { name: 'X', intervalDays: 0 },
      { name: 'X', intervalDays: -5 },
      { name: 'X', intervalDays: 1.5 },
      { name: 'X', intervalKm: 0 },
      { name: 'X', intervalKm: 'mil' },
      { name: 'X', intervalDays: 3651 },
      { name: '', intervalDays: 10 },
      { name: 'Y'.repeat(101), intervalDays: 10 },
      { name: 'X', intervalDays: 10, desconocido: 1 },
    ]) {
      const res = await crear(cuerpo);
      expect({ cuerpo, estado: res.status }).toEqual({ cuerpo, estado: 400 });
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('test_no_se_puede_quitar_el_ultimo_intervalo_de_un_tipo', async () => {
    const tipo = await createServiceType({ intervalDays: 30, intervalKm: null });
    const res = await request(app).patch(`/api/service-types/${tipo.id}`).set(auth(admin.token)).send({ intervalDays: null });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SERVICE_TYPE_INTERVAL_REQUIRED');
  });

  it('test_un_tipo_en_uso_se_desactiva_sin_tocar_las_ordenes_y_cuenta_sus_lineas', async () => {
    const tipo = await createServiceType();
    const linea = await lineaServicio({ serviceTypeId: tipo.id });
    expect(linea.status).toBe(201);
    expect(linea.body.data.item.serviceType).toEqual({ id: tipo.id, name: tipo.name });

    const lista = await request(app).get('/api/service-types').set(auth(admin.token));
    expect(lista.body.data[0].inUse).toBe(1);

    await request(app).patch(`/api/service-types/${tipo.id}`).set(auth(admin.token)).send({ active: false });
    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(admin.token));
    expect(detalle.body.data.services[0].serviceType).toEqual({ id: tipo.id, name: tipo.name });
  });

  it('test_options_devuelve_solo_los_activos_para_admin_y_mecanico_y_403_para_recepcion', async () => {
    const activo = await createServiceType({ name: 'Activo' });
    await createServiceType({ name: 'Inactivo', active: 0 });

    for (const token of [admin.token, mecanico.token]) {
      const res = await request(app).get('/api/service-types/options').set(auth(token));
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([{ id: activo.id, name: 'Activo', intervalDays: 180, intervalKm: 5000 }]);
    }
    expect((await request(app).get('/api/service-types/options').set(auth(recepcion.token))).status).toBe(403);
  });

  it('test_la_linea_acepta_tipo_un_tipo_inexistente_da_404_y_uno_desactivado_se_rechaza', async () => {
    const inactivo = await createServiceType({ active: 0 });

    expect((await lineaServicio({ serviceTypeId: 99999 })).status).toBe(404);
    const rechazada = await lineaServicio({ serviceTypeId: inactivo.id });
    expect(rechazada.status).toBe(422);
    expect(rechazada.body.error.code).toBe('SERVICE_TYPE_INACTIVE');

    const sinTipo = await lineaServicio({});
    expect(sinTipo.status).toBe(201);
    expect(sinTipo.body.data.item.serviceType).toBeNull();
  });

  it('test_la_mano_de_obra_no_acepta_tipo_de_servicio', async () => {
    const tipo = await createServiceType();
    const res = await request(app)
      .post(`/api/orders/${orden.id}/labor`)
      .set(auth(mecanico.token))
      .send({ description: 'Mano de obra', amount: 100, serviceTypeId: tipo.id });

    expect(res.status).toBe(400);
  });

  it('test_se_puede_cambiar_o_quitar_el_tipo_de_una_linea_existente', async () => {
    const tipo = await createServiceType();
    const linea = await createService(orden.id);
    const asignado = await request(app).patch(`/api/orders/${orden.id}/services/${linea.id}`).set(auth(mecanico.token)).send({ serviceTypeId: tipo.id });
    expect(asignado.body.data.item.serviceType).toEqual({ id: tipo.id, name: tipo.name });

    const quitado = await request(app).patch(`/api/orders/${orden.id}/services/${linea.id}`).set(auth(mecanico.token)).send({ serviceTypeId: null });
    expect(quitado.body.data.item.serviceType).toBeNull();
  });

  it('test_las_lineas_existentes_llegan_con_tipo_nulo', async () => {
    await createService(orden.id);
    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(admin.token));

    expect(detalle.body.data.services[0].serviceType).toBeNull();
  });

  it('test_los_cambios_quedan_en_la_bitacora_como_service_type_changed', async () => {
    const alta = await crear({ name: 'Afinación', intervalDays: 365 });
    await request(app).patch(`/api/service-types/${alta.body.data.id}`).set(auth(admin.token)).send({ active: false });

    const filas = await query("SELECT summary FROM audit_log WHERE action = 'SERVICE_TYPE_CHANGED' ORDER BY id");
    expect(filas).toHaveLength(2);
    expect(filas[0].summary).toContain('Afinación');
  });
});
