import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createOrder, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

/** Crea `cantidad` órdenes en reparación asignadas al mecánico, cada una de un vehículo distinto. */
async function crearOrdenes(cantidad) {
  const ordenes = [];
  for (let i = 0; i < cantidad; i += 1) {
    const { vehicle } = await createClientWithVehicle({ licensePlate: `CON-${String(i).padStart(3, '0')}-Z` });
    ordenes.push(await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' }));
  }
  return ordenes;
}

const usar = (orden, parte, cantidad, user = mecanico) =>
  request(app).post(`/api/orders/${orden.id}/parts`).set(auth(user.token)).send({ partId: parte.id, quantity: cantidad });

async function verificaStock(parte) {
  const [{ stock }] = await query('SELECT stock FROM parts WHERE id = ?', [parte.id]);
  const [{ suma }] = await query('SELECT COALESCE(SUM(quantity), 0) AS suma FROM inventory_movements WHERE part_id = ?', [parte.id]);
  expect(stock).toBeGreaterThanOrEqual(0);
  expect(Number(suma)).toBe(stock);
  return stock;
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('stock con solicitudes simultáneas (SC-005, RN-8)', () => {
  it('test_cinco_ordenes_piden_dos_unidades_de_un_stock_de_siete_y_solo_caben_tres', async () => {
    const parte = await createPart(admin.id, { stock: 7, minStock: 1 });
    const ordenes = await crearOrdenes(5);

    const respuestas = await Promise.all(ordenes.map((orden) => usar(orden, parte, 2)));

    const aceptadas = respuestas.filter((r) => r.status === 201);
    const rechazadas = respuestas.filter((r) => r.status === 409);
    expect(aceptadas).toHaveLength(3);
    expect(rechazadas).toHaveLength(2);
    for (const rechazada of rechazadas) expect(rechazada.body.error.code).toBe('INSUFFICIENT_STOCK');
    expect(await verificaStock(parte)).toBe(1);
    const [{ lineas }] = await query('SELECT COUNT(*) AS lineas FROM order_parts WHERE part_id = ?', [parte.id]);
    expect(Number(lineas)).toBe(3);
  });

  it('test_diez_solicitudes_de_una_unidad_contra_un_stock_de_cuatro_dejan_el_stock_en_cero', async () => {
    const parte = await createPart(admin.id, { stock: 4, minStock: 1 });
    const ordenes = await crearOrdenes(10);

    const respuestas = await Promise.all(ordenes.map((orden) => usar(orden, parte, 1)));

    expect(respuestas.filter((r) => r.status === 201)).toHaveLength(4);
    expect(respuestas.filter((r) => r.status === 409)).toHaveLength(6);
    expect(await verificaStock(parte)).toBe(0);
  });

  it('test_varias_solicitudes_sobre_la_misma_orden_se_serializan_y_suman_una_sola_linea', async () => {
    const parte = await createPart(admin.id, { stock: 10, minStock: 1 });
    const [orden] = await crearOrdenes(1);

    const respuestas = await Promise.all([1, 2, 3, 4].map(() => usar(orden, parte, 3)));

    expect(respuestas.filter((r) => r.status === 201)).toHaveLength(3);
    expect(respuestas.filter((r) => r.status === 409)).toHaveLength(1);
    expect(await verificaStock(parte)).toBe(1);
    const lineas = await query('SELECT quantity FROM order_parts WHERE order_id = ?', [orden.id]);
    expect(lineas).toEqual([{ quantity: 9 }]);
  });

  it('test_un_uso_y_un_ajuste_simultaneos_nunca_dejan_el_stock_negativo', async () => {
    const parte = await createPart(admin.id, { stock: 5, minStock: 1 });
    const [orden] = await crearOrdenes(1);

    const [uso, ajuste] = await Promise.all([
      usar(orden, parte, 5),
      request(app)
        .post(`/api/parts/${parte.id}/movements`)
        .set(auth(admin.token))
        .send({ type: 'ADJUSTMENT', countedQuantity: 2, reason: 'Conteo físico simultáneo' }),
    ]);

    expect([201, 409]).toContain(uso.status);
    expect([201, 422]).toContain(ajuste.status);
    const stock = await verificaStock(parte);
    expect(stock).toBeGreaterThanOrEqual(0);
  });

  it('test_usar_y_devolver_al_mismo_tiempo_conserva_la_invariante', async () => {
    const parte = await createPart(admin.id, { stock: 6, minStock: 1 });
    const ordenes = await crearOrdenes(4);
    const inicial = await usar(ordenes[0], parte, 3);
    const lineId = inicial.body.data.item.id;

    await Promise.all([
      request(app).delete(`/api/orders/${ordenes[0].id}/parts/${lineId}`).set(auth(mecanico.token)),
      usar(ordenes[1], parte, 2),
      usar(ordenes[2], parte, 2),
      usar(ordenes[3], parte, 2),
    ]);

    const stock = await verificaStock(parte);
    expect(stock).toBeGreaterThanOrEqual(0);
    expect(stock).toBeLessThanOrEqual(6);
  });
});
