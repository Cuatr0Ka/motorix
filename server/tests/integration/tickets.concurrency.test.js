import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createPayment,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let mecanico;

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('un solo ticket por orden con solicitudes simultáneas (FR-012)', () => {
  it('test_seis_generaciones_simultaneas_crean_un_solo_ticket_y_todas_devuelven_el_mismo', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'TCO-001-A' });
    const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
    await createPayment(orden.id, recepcion.id);

    const respuestas = await Promise.all(
      Array.from({ length: 6 }, (_, i) => request(app).post(`/api/orders/${orden.id}/ticket`).set(auth((i % 2 ? admin : recepcion).token))),
    );

    expect(respuestas.every((r) => r.status === 200 || r.status === 201)).toBe(true);
    expect(respuestas.filter((r) => r.status === 201)).toHaveLength(1);
    expect(new Set(respuestas.map((r) => r.body.data.ticket.id)).size).toBe(1);
    expect(await query('SELECT id FROM tickets WHERE order_id = ?', [orden.id])).toHaveLength(1);
  });

  it('test_las_ordenes_distintas_generan_cada_una_su_propio_ticket', async () => {
    const ordenes = [];
    for (let i = 0; i < 3; i += 1) {
      const { vehicle } = await createClientWithVehicle({ licensePlate: `TCO-10${i}-B` });
      const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
      await createPayment(orden.id, recepcion.id);
      ordenes.push(orden);
    }

    const respuestas = await Promise.all(ordenes.map((orden) => request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token))));

    expect(respuestas.map((r) => r.status)).toEqual([201, 201, 201]);
    const folios = respuestas.map((r) => r.body.data.ticket.folio);
    expect(new Set(folios).size).toBe(3);
  });
});
