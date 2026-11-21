import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('avisos a clientes: concurrencia (FR-021, R-04)', () => {
  it('test_cinco_avisos_simultaneos_del_mismo_hecho_dejan_una_sola_fila', async () => {
    const { vehicle } = await createClientWithVehicle({ currentMileage: 1000 });
    const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 });
    const personas = [recepcion, admin, recepcion, admin, recepcion];

    const respuestas = await Promise.all(
      personas.map((persona) =>
        request(app)
          .post('/api/client-notices')
          .set(auth(persona.token))
          .send({ reason: 'ORDER_READY', factId: orden.id }),
      ),
    );

    const estados = respuestas.map((r) => r.status).sort();
    expect(estados).toEqual([200, 200, 200, 200, 201]);
    for (const res of respuestas) expect(res.body.data.factId).toBe(orden.id);
    expect(new Set(respuestas.map((r) => r.body.data.id)).size).toBe(1);
    expect((await query('SELECT id FROM client_notices')).length).toBe(1);
  });

  it('test_avisos_simultaneos_de_hechos_distintos_crean_una_fila_por_hecho', async () => {
    const ordenes = [];
    for (let i = 0; i < 4; i += 1) {
      const { vehicle } = await createClientWithVehicle({ licensePlate: `CON-${i}00-Z`, currentMileage: 1000 });
      ordenes.push(await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO', entryMileage: 0 }));
    }

    const respuestas = await Promise.all(
      ordenes.map((orden) =>
        request(app).post('/api/client-notices').set(auth(recepcion.token)).send({ reason: 'ORDER_READY', factId: orden.id }),
      ),
    );

    for (const res of respuestas) expect(res.status).toBe(201);
    expect((await query('SELECT id FROM client_notices')).length).toBe(4);
  });
});
