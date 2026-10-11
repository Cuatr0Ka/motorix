import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createClient, createUserWithToken, createVehicle, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let recepcion;
let ana;
let luis;
let vehiculo;

const patch = (id, body, token = recepcion.token) =>
  request(app).patch(`/api/vehicles/${id}`).set(auth(token)).send(body);
const detalleCliente = async (id) =>
  (await request(app).get(`/api/clients/${id}`).set(auth(recepcion.token))).body.data;

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  ana = await createClient({ name: 'Ana Morales' });
  luis = await createClient({ name: 'Luis Pérez' });
  vehiculo = await createVehicle(ana.id, { currentMileage: 50000 });
});

describe('cambio de propietario', () => {
  it('test_el_vehiculo_deja_de_aparecer_en_el_cliente_anterior_y_aparece_en_el_nuevo', async () => {
    const res = await patch(vehiculo.id, { clientId: luis.id });

    expect(res.status).toBe(200);
    expect(res.body.data.client.id).toBe(luis.id);
    expect((await detalleCliente(ana.id)).vehicles).toHaveLength(0);
    expect((await detalleCliente(luis.id)).vehicles.map((v) => v.id)).toEqual([vehiculo.id]);
  });

  it('test_el_listado_muestra_al_propietario_nuevo_y_el_filtro_por_cliente_se_actualiza', async () => {
    await patch(vehiculo.id, { clientId: luis.id });

    const deAna = await request(app).get(`/api/vehicles?clientId=${ana.id}`).set(auth(recepcion.token));
    const deLuis = await request(app).get(`/api/vehicles?clientId=${luis.id}`).set(auth(recepcion.token));

    expect(deAna.body.data).toHaveLength(0);
    expect(deLuis.body.data[0].client).toEqual({ id: luis.id, name: 'Luis Pérez' });
  });

  it('test_rechaza_un_propietario_inexistente_con_422_y_conserva_al_actual', async () => {
    const res = await patch(vehiculo.id, { clientId: 999999 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('OWNER_NOT_FOUND');
    const actual = await request(app).get(`/api/vehicles/${vehiculo.id}`).set(auth(recepcion.token));
    expect(actual.body.data.client.id).toBe(ana.id);
  });

  it('test_un_propietario_nulo_es_invalido_porque_todo_vehiculo_necesita_dueño', async () => {
    const res = await patch(vehiculo.id, { clientId: null });

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('clientId');
  });
});

describe('regla de kilometraje (no puede disminuir sin corrección explícita)', () => {
  it('test_rechaza_un_kilometraje_menor_con_422', async () => {
    const res = await patch(vehiculo.id, { currentMileage: 49999 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MILEAGE_DECREASE');
    const actual = await request(app).get(`/api/vehicles/${vehiculo.id}`).set(auth(recepcion.token));
    expect(actual.body.data.currentMileage).toBe(50000);
  });

  it('test_acepta_el_kilometraje_menor_con_mileageCorrection', async () => {
    const res = await patch(vehiculo.id, { currentMileage: 40000, mileageCorrection: true });

    expect(res.status).toBe(200);
    expect(res.body.data.currentMileage).toBe(40000);
  });

  it('test_acepta_un_kilometraje_igual_o_mayor_sin_correccion', async () => {
    expect((await patch(vehiculo.id, { currentMileage: 50000 })).status).toBe(200);
    expect((await patch(vehiculo.id, { currentMileage: 52000 })).body.data.currentMileage).toBe(52000);
  });

  it('test_un_vehiculo_sin_kilometraje_previo_acepta_cualquier_valor', async () => {
    const otro = await createVehicle(ana.id, { currentMileage: null });

    expect((await patch(otro.id, { currentMileage: 10 })).status).toBe(200);
  });

  it('test_la_bandera_de_correccion_no_se_guarda_ni_se_devuelve', async () => {
    const res = await patch(vehiculo.id, { currentMileage: 40000, mileageCorrection: true });

    expect(res.body.data.mileageCorrection).toBeUndefined();
  });

  it('test_se_puede_borrar_el_kilometraje_solo_con_correccion_explicita', async () => {
    expect((await patch(vehiculo.id, { currentMileage: null })).status).toBe(422);
    expect((await patch(vehiculo.id, { currentMileage: null, mileageCorrection: true })).status).toBe(200);
  });
});

describe('duplicados al editar', () => {
  it('test_rechaza_la_placa_de_otro_vehiculo_pero_acepta_conservar_la_propia', async () => {
    const otro = await createVehicle(luis.id, { licensePlate: 'OTR-111-A' });

    const conflicto = await patch(vehiculo.id, { licensePlate: ' otr-111-a ' });
    const propia = await patch(vehiculo.id, { licensePlate: vehiculo.licensePlate.toLowerCase(), color: 'Azul' });

    expect(conflicto.status).toBe(409);
    expect(conflicto.body.error.code).toBe('PLATE_DUPLICATE');
    expect(propia.status).toBe(200);
    expect(otro.id).not.toBe(vehiculo.id);
  });

  it('test_rechaza_el_vin_de_otro_vehiculo', async () => {
    await createVehicle(luis.id, { vin: '2HGFC2F59LH345678' });

    const res = await patch(vehiculo.id, { vin: '2hgfc2f59lh345678' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('VIN_DUPLICATE');
  });

  it('test_una_edicion_rechazada_no_modifica_ningun_campo', async () => {
    await createVehicle(luis.id, { licensePlate: 'OTR-111-A' });

    await patch(vehiculo.id, { brand: 'Cambiada', licensePlate: 'OTR-111-A' });

    const actual = await request(app).get(`/api/vehicles/${vehiculo.id}`).set(auth(recepcion.token));
    expect(actual.body.data.brand).toBe('Nissan');
  });

  it('test_se_pueden_borrar_vin_y_color_enviando_vacio', async () => {
    const conDatos = await createVehicle(ana.id, { vin: '2HGFC2F59LH345678', color: 'Azul' });

    const res = await patch(conDatos.id, { vin: '', color: '' });

    expect(res.status).toBe(200);
    expect(res.body.data.vin).toBeNull();
    expect(res.body.data.color).toBeNull();
  });
});
