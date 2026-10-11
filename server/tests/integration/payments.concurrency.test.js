import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let mecanico;

const cobrar = (id, metodo, user = recepcion) => request(app).post(`/api/orders/${id}/payments`).set(auth(user.token)).send({ method: metodo });

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
});

afterAll(() => resetGateway());

describe('un solo pago vigente por orden con solicitudes simultáneas (SC-005)', () => {
  it('test_cinco_cobros_simultaneos_con_metodos_distintos_dejan_un_solo_pago', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'CON-001-A' });
    const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);

    const respuestas = await Promise.all(
      ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO', 'EFECTIVO'].map((metodo, i) => cobrar(orden.id, metodo, i % 2 ? admin : recepcion)),
    );

    const creados = respuestas.filter((r) => r.status === 201);
    const rechazados = respuestas.filter((r) => r.status === 409);
    expect(creados).toHaveLength(1);
    expect(rechazados).toHaveLength(4);
    for (const rechazado of rechazados) expect(rechazado.body.error.code).toBe('PAYMENT_ALREADY_EXISTS');
    const vigentes = await query("SELECT id FROM payments WHERE order_id = ? AND status IN ('PENDIENTE','PAGADO')", [orden.id]);
    expect(vigentes).toHaveLength(1);
    const todos = await query('SELECT id FROM payments WHERE order_id = ?', [orden.id]);
    expect(todos).toHaveLength(1);
  });

  it('test_cobros_simultaneos_de_ordenes_distintas_prosperan_todos', async () => {
    const ordenes = [];
    for (let i = 0; i < 4; i += 1) {
      const { vehicle } = await createClientWithVehicle({ licensePlate: `CON-10${i}-B` });
      ordenes.push(await createPayableOrder(vehicle.id, recepcion.id, mecanico.id));
    }

    const respuestas = await Promise.all(ordenes.map((orden) => cobrar(orden.id, 'EFECTIVO')));

    expect(respuestas.map((r) => r.status)).toEqual([201, 201, 201, 201]);
  });

  it('test_un_cobro_de_mercado_pago_pendiente_bloquea_otro_simultaneo_y_solo_llama_una_vez_al_proveedor', async () => {
    const gateway = new FakeGateway({ configured: true });
    setGateway(gateway);
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'CON-201-C' });
    const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);

    const respuestas = await Promise.all([cobrar(orden.id, 'MERCADO_PAGO'), cobrar(orden.id, 'MERCADO_PAGO'), cobrar(orden.id, 'MERCADO_PAGO')]);

    expect(respuestas.filter((r) => r.status === 201)).toHaveLength(1);
    expect(respuestas.filter((r) => r.status === 409)).toHaveLength(2);
    expect(gateway.checkouts).toHaveLength(1);
  });
});
