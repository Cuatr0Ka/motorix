import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createMaintenance,
  createPayableOrder,
  createPayment,
  createTicket,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let vehiculo;
let orden;

const cobrarYGenerar = async () => {
  await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
  return request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));
};

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'NXT-001-A' }));
  orden = await createPayableOrder(vehiculo.id, recepcion.id, mecanico.id);
});

afterAll(() => resetGateway());

describe('próximo servicio en el ticket (US8, FR-009)', () => {
  it('test_el_ticket_de_una_orden_con_mantenimiento_pendiente_incluye_next_service', async () => {
    await createMaintenance(vehiculo.id, orden.id, mecanico.id, {
      description: 'Cambio de aceite',
      dueDate: new Date(2031, 4, 20),
      dueMileage: 90000,
    });

    const res = await cobrarYGenerar();

    expect(res.body.data.ticket.content.formatVersion).toBe(3);
    expect(res.body.data.ticket.content.nextService).toEqual({ dueDate: '2031-05-20', dueMileage: 90000, description: 'Cambio de aceite' });
  });

  it('test_sin_mantenimiento_no_incluye_el_bloque_y_sigue_en_version_2', async () => {
    const res = await cobrarYGenerar();

    expect(res.body.data.ticket.content.formatVersion).toBe(2);
    expect(res.body.data.ticket.content).not.toHaveProperty('nextService');
  });

  it('test_un_mantenimiento_atendido_o_de_otra_orden_no_aparece', async () => {
    await createMaintenance(vehiculo.id, orden.id, mecanico.id, { status: 'ATENDIDO' });

    const res = await cobrarYGenerar();

    expect(res.body.data.ticket.content).not.toHaveProperty('nextService');
  });

  it('test_corregir_el_mantenimiento_despues_de_emitir_no_cambia_el_ticket', async () => {
    const mantenimiento = await createMaintenance(vehiculo.id, orden.id, mecanico.id, { dueDate: null, dueMileage: 80000 });
    const emitido = await cobrarYGenerar();

    await query('UPDATE maintenance SET due_mileage = 99999, description = ? WHERE id = ?', ['Otro servicio', mantenimiento.id]);
    const consulta = await request(app).get(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    expect(consulta.body.data.content.nextService).toEqual(emitido.body.data.ticket.content.nextService);
    expect(consulta.body.data.content.nextService.dueMileage).toBe(80000);
  });

  it('test_un_ticket_emitido_antes_en_version_1_o_2_se_consulta_identico', async () => {
    const pago = await createPayment(orden.id, recepcion.id);
    const v1 = { generatedAt: '2026-01-01T00:00:00.000Z', shop: { name: 'Antiguo' } };
    await createTicket(orden.id, pago.id, recepcion.id, { content: v1 });

    const res = await request(app).get(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));

    expect(res.body.data.content).toEqual(v1);
  });
});
