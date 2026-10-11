import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClient, createUserWithToken, createVehicle, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let recepcion;
let cliente;

const crear = (body) => request(app).post('/api/vehicles').set(auth(recepcion.token)).send(body);
const base = (extra = {}) => ({
  clientId: cliente.id,
  brand: 'Honda',
  model: 'Civic',
  year: 2020,
  licensePlate: 'MNO-345-E',
  ...extra,
});

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  cliente = await createClient({ name: 'Ana Morales' });
});

describe('propietario obligatorio (RN-1)', () => {
  it('test_rechaza_un_vehiculo_sin_propietario', async () => {
    const { clientId, ...sinPropietario } = base();

    const res = await crear(sinPropietario);

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('clientId');
    expect(clientId).toBeDefined();
  });

  it('test_rechaza_un_propietario_inexistente_con_422_y_no_guarda_nada', async () => {
    const res = await crear(base({ clientId: 999999 }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('OWNER_NOT_FOUND');
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM vehicles');
    expect(total).toBe(0);
  });

  it('test_la_base_impide_borrar_un_cliente_que_tiene_vehiculos', async () => {
    await createVehicle(cliente.id);

    await expect(query('DELETE FROM clients WHERE id = ?', [cliente.id])).rejects.toMatchObject({
      code: 'ER_ROW_IS_REFERENCED_2',
    });
  });
});

describe('unicidad de placa y VIN', () => {
  it('test_rechaza_una_placa_repetida_aunque_cambie_la_capitalizacion_y_los_espacios', async () => {
    await createVehicle(cliente.id, { licensePlate: 'MNO-345-E' });

    const res = await crear(base({ licensePlate: ' mno-345-e ' }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PLATE_DUPLICATE');
  });

  it('test_rechaza_un_vin_repetido', async () => {
    await createVehicle(cliente.id, { vin: '2HGFC2F59LH345678' });

    const res = await crear(base({ licensePlate: 'OTR-111-A', vin: '2hgfc2f59lh345678' }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('VIN_DUPLICATE');
  });

  it('test_permite_varios_vehiculos_sin_vin', async () => {
    const a = await crear(base({ licensePlate: 'AAA-111-A', vin: '' }));
    const b = await crear(base({ licensePlate: 'BBB-222-B' }));

    expect(a.status).toBe(201);
    expect(b.status).toBe(201);
    expect(a.body.data.vin).toBeNull();
  });
});

describe('validación de datos del vehículo', () => {
  const anioActual = new Date().getFullYear();

  it.each([
    ['anio anterior a 1950', { year: 1949 }, 'year'],
    ['anio posterior al actual + 1', { year: anioActual + 2 }, 'year'],
    ['anio no entero', { year: 2020.5 }, 'year'],
    ['marca de mas de 60 caracteres', { brand: 'M'.repeat(61) }, 'brand'],
    ['modelo en blanco', { model: '   ' }, 'model'],
    ['placa de mas de 15 caracteres', { licensePlate: 'P'.repeat(16) }, 'licensePlate'],
    ['vin de 16 caracteres', { vin: '2HGFC2F59LH34567' }, 'vin'],
    ['vin con la letra I', { vin: '2HGFC2F59LI345678' }, 'vin'],
    ['vin con la letra O', { vin: '2HGFC2F59LO345678' }, 'vin'],
    ['vin con la letra Q', { vin: '2HGFC2F59LQ345678' }, 'vin'],
    ['color de mas de 40 caracteres', { color: 'C'.repeat(41) }, 'color'],
    ['kilometraje negativo', { currentMileage: -1 }, 'currentMileage'],
    ['kilometraje decimal', { currentMileage: 10.5 }, 'currentMileage'],
  ])('test_rechaza_%s', async (_nombre, extra, campo) => {
    const res = await crear(base(extra));

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });

  it('test_acepta_los_limites_del_anio_1950_y_el_actual_mas_uno', async () => {
    expect((await crear(base({ licensePlate: 'LIM-001-A', year: 1950 }))).status).toBe(201);
    expect((await crear(base({ licensePlate: 'LIM-002-A', year: anioActual + 1 }))).status).toBe(201);
  });
});

describe('búsqueda y filtros del listado', () => {
  beforeEach(async () => {
    const luis = await createClient({ name: 'Luis Pérez' });
    await createVehicle(cliente.id, { brand: 'Honda', model: 'Civic', licensePlate: 'AAA-111-A' });
    await createVehicle(cliente.id, { brand: 'Toyota', model: 'Hilux', licensePlate: 'BBB-222-B' });
    await createVehicle(luis.id, { brand: 'Honda', model: 'Fit', licensePlate: 'CCC-333-C' });
  });

  const buscar = async (qs) => (await request(app).get(`/api/vehicles?${qs}`).set(auth(recepcion.token))).body;

  it('test_busca_por_placa', async () => {
    expect((await buscar('search=bbb')).data.map((v) => v.licensePlate)).toEqual(['BBB-222-B']);
  });

  it('test_busca_por_marca', async () => {
    expect((await buscar('search=honda')).data.map((v) => v.licensePlate)).toEqual(['AAA-111-A', 'CCC-333-C']);
  });

  it('test_busca_por_modelo', async () => {
    expect((await buscar('search=hilux')).data).toHaveLength(1);
  });

  it('test_busca_por_nombre_del_propietario', async () => {
    const body = await buscar('search=luis');
    expect(body.data.map((v) => v.licensePlate)).toEqual(['CCC-333-C']);
    expect(body.meta.total).toBe(1);
  });

  it('test_filtra_por_cliente', async () => {
    const body = await buscar(`clientId=${cliente.id}`);
    expect(body.data).toHaveLength(2);
    expect(body.data.every((v) => v.client.id === cliente.id)).toBe(true);
  });

  it('test_pagina_los_resultados', async () => {
    const body = await buscar('pageSize=2&page=2');
    expect(body.data).toHaveLength(1);
    expect(body.meta).toEqual({ page: 2, pageSize: 2, total: 3 });
  });
});
