import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createPart,
  createPayableOrder,
  createPayment,
  createTicket,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;

const CARGAS = ["' OR '1'='1", '%', '_', '\\', '--', '; DROP TABLE clients;--', '" OR ""="'];
const TABLAS = ['clients', 'vehicles', 'appointments', 'service_orders', 'parts', 'users', 'maintenance', 'payments', 'tickets'];
const RUTAS = ['clients', 'vehicles', 'appointments', 'orders', 'parts', 'users', 'maintenance', 'payments', 'tickets'];

const conteos = async () => {
  const resultado = {};
  for (const tabla of TABLAS) resultado[tabla] = Number((await query(`SELECT COUNT(*) AS n FROM ${tabla}`))[0].n);
  return resultado;
};

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  const mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'INY-001-A' }, { name: 'Ana Morales' });
  const orden = await createPayableOrder(vehicle.id, admin.id, mecanico.id);
  await createPart(admin.id, { name: 'Balatas', code: 'BAL-001' });
  const pago = await createPayment(orden.id, admin.id);
  await createTicket(orden.id, pago.id, admin.id);
});

describe('inyección en los campos de búsqueda (US10, FR-018)', () => {
  it('test_las_cargas_no_producen_errores_500_ni_mas_filas_que_las_coincidencias_literales_y_las_tablas_siguen_intactas', async () => {
    const antes = await conteos();

    for (const ruta of RUTAS) {
      for (const carga of CARGAS) {
        const res = await request(app).get(`/api/${ruta}`).query({ search: carga }).set(auth(admin.token));
        expect({ ruta, carga, error500: res.status >= 500 }).toEqual({ ruta, carga, error500: false });
        // Ningún dato de prueba contiene estos textos: una coincidencia literal devuelve 0 filas.
        if (res.status === 200 && Array.isArray(res.body.data)) {
          expect({ ruta, carga, filas: res.body.data.length }).toEqual({ ruta, carga, filas: 0 });
        }
      }
    }

    expect(await conteos()).toEqual(antes);
  });

  it('test_una_busqueda_normal_sigue_encontrando_la_fila_correcta', async () => {
    const res = await request(app).get('/api/clients').query({ search: 'Ana' }).set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });
});
