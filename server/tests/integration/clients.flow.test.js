import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClient,
  createUserWithToken,
  createVehicle,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;

const crear = (body) => request(app).post('/api/clients').set(auth(recepcion.token)).send(body);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
});

describe('búsqueda y paginación de clientes', () => {
  beforeEach(async () => {
    await createClient({ name: 'María Fernanda López', phone: '5511110000', email: 'maria@x.local' });
    await createClient({ name: 'Jorge Ramírez', phone: '5522220000', email: 'jorge@x.local' });
    await createClient({ name: 'Marisol Díaz', phone: '5533330000', email: 'marisol@x.local' });
  });

  it('test_busca_por_nombre_sin_distinguir_mayusculas_ni_acentos', async () => {
    const res = await request(app).get('/api/clients?search=mari').set(auth(recepcion.token));

    expect(res.body.data.map((c) => c.name)).toEqual(['María Fernanda López', 'Marisol Díaz']);
    expect(res.body.meta.total).toBe(2);
  });

  it('test_busca_por_telefono', async () => {
    const res = await request(app).get('/api/clients?search=5522').set(auth(recepcion.token));

    expect(res.body.data.map((c) => c.name)).toEqual(['Jorge Ramírez']);
  });

  it('test_los_comodines_de_like_se_tratan_como_texto', async () => {
    const res = await request(app).get('/api/clients?search=%25').set(auth(recepcion.token));

    expect(res.body.data).toEqual([]);
    expect(res.body.meta.total).toBe(0);
  });

  it('test_pagina_los_resultados_ordenados_por_nombre', async () => {
    const primera = await request(app).get('/api/clients?pageSize=2&page=1').set(auth(recepcion.token));
    const segunda = await request(app).get('/api/clients?pageSize=2&page=2').set(auth(recepcion.token));

    expect(primera.body.data.map((c) => c.name)).toEqual(['Jorge Ramírez', 'María Fernanda López']);
    expect(segunda.body.data.map((c) => c.name)).toEqual(['Marisol Díaz']);
    expect(primera.body.meta).toEqual({ page: 1, pageSize: 2, total: 3 });
  });

  it('test_rechaza_un_tamano_de_pagina_mayor_a_100', async () => {
    expect((await request(app).get('/api/clients?pageSize=101').set(auth(recepcion.token))).status).toBe(400);
  });
});

describe('reglas de duplicados al registrar', () => {
  it('test_un_correo_repetido_responde_409_y_no_se_puede_confirmar', async () => {
    await createClient({ email: 'repetido@x.local' });

    const res = await crear({ name: 'Otra Persona', phone: '5599998888', email: 'REPETIDO@x.local', confirmDuplicatePhone: true });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_DUPLICATE');
  });

  it('test_un_telefono_repetido_responde_409_con_las_coincidencias', async () => {
    const existente = await createClient({ name: 'Ana Morales', phone: '55 1234-5678' });

    const res = await crear({ name: 'Luis Morales', phone: '(55) 12345678' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PHONE_DUPLICATE');
    expect(res.body.error.details.matches).toEqual([{ id: existente.id, name: 'Ana Morales', phone: '55 1234-5678' }]);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM clients');
    expect(total).toBe(1);
  });

  it('test_un_telefono_repetido_se_guarda_si_se_confirma', async () => {
    await createClient({ phone: '5512345678' });

    const res = await crear({ name: 'Luis Morales', phone: '5512345678', confirmDuplicatePhone: true });

    expect(res.status).toBe(201);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM clients');
    expect(total).toBe(2);
  });

  it('test_el_correo_vacio_se_guarda_como_nulo_y_permite_varios_clientes_sin_correo', async () => {
    const a = await crear({ name: 'Sin Correo Uno', phone: '5511110001', email: '' });
    const b = await crear({ name: 'Sin Correo Dos', phone: '5511110002' });

    expect(a.status).toBe(201);
    expect(b.status).toBe(201);
    expect(a.body.data.email).toBeNull();
    const rows = await query('SELECT email FROM clients WHERE email IS NULL');
    expect(rows).toHaveLength(2);
  });
});

describe('validación de datos del cliente', () => {
  it.each([
    ['telefono con letras', { name: 'Ana', phone: '55abc12345' }, 'phone'],
    ['telefono con menos de 7 digitos', { name: 'Ana', phone: '12345' }, 'phone'],
    ['telefono de mas de 20 caracteres', { name: 'Ana', phone: '5'.repeat(21) }, 'phone'],
    ['nombre de mas de 120 caracteres', { name: 'A'.repeat(121), phone: '5512345678' }, 'name'],
    ['nombre en blanco', { name: '   ', phone: '5512345678' }, 'name'],
    ['correo invalido', { name: 'Ana', phone: '5512345678', email: 'sin-arroba' }, 'email'],
    ['direccion de mas de 255 caracteres', { name: 'Ana', phone: '5512345678', address: 'x'.repeat(256) }, 'address'],
  ])('test_rechaza_%s', async (_nombre, body, campo) => {
    const res = await crear(body);

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });
});

describe('detalle del cliente con vehículos', () => {
  it('test_el_detalle_incluye_unicamente_los_vehiculos_de_ese_cliente', async () => {
    const ana = await createClient({ name: 'Ana' });
    const luis = await createClient({ name: 'Luis' });
    await createVehicle(ana.id);
    await createVehicle(ana.id);
    await createVehicle(luis.id);

    const res = await request(app).get(`/api/clients/${ana.id}`).set(auth(recepcion.token));

    expect(res.body.data.vehicles).toHaveLength(2);
  });
});
