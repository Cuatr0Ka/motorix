import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createOrder,
  createPart,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let otroMecanico;
let orden;
let parte;

const agregar = (user, cuerpo, id = orden.id) => request(app).post(`/api/orders/${id}/parts`).set(auth(user.token)).send(cuerpo);
const corregir = (user, lineId, cantidad, id = orden.id) =>
  request(app).patch(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token)).send({ quantity: cantidad });
const quitar = (user, lineId, id = orden.id) => request(app).delete(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token));
const stockDe = async (id = parte.id) => (await query('SELECT stock FROM parts WHERE id = ?', [id]))[0].stock;
const movimientos = (id = parte.id) =>
  query('SELECT type, quantity, reason, order_id AS orderId FROM inventory_movements WHERE part_id = ? ORDER BY id', [id]);
const lineas = (id = orden.id) => query('SELECT part_id AS partId, quantity FROM order_parts WHERE order_id = ?', [id]);

/** Invariante: el stock de cada refacción es la suma de sus movimientos (SC-006). */
async function verificaInvariante() {
  const filas = await query(
    `SELECT p.stock, COALESCE(SUM(m.quantity), 0) AS suma
       FROM parts p LEFT JOIN inventory_movements m ON m.part_id = p.id GROUP BY p.id, p.stock`,
  );
  for (const fila of filas) expect(Number(fila.suma)).toBe(fila.stock);
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPA-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  parte = await createPart(admin.id, { code: 'OPA-REF', name: 'Balatas', stock: 10, minStock: 3 });
});

describe('agregar refacciones a una orden (US4, CA-5)', () => {
  it('test_agrega_descuenta_el_stock_y_registra_la_salida_ligada_a_la_orden', async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 3 });

    expect(res.status).toBe(201);
    expect(res.body.data.item).toMatchObject({ partId: parte.id, code: 'OPA-REF', name: 'Balatas', quantity: 3 });
    expect(res.body.data.part).toMatchObject({ id: parte.id, stock: 7 });
    expect(await stockDe()).toBe(7);
    expect(await lineas()).toEqual([{ partId: parte.id, quantity: 3 }]);
    expect((await movimientos()).slice(1)).toEqual([
      { type: 'OUT', quantity: -3, reason: `Uso en OS-${String(orden.id).padStart(6, '0')}`, orderId: orden.id },
    ]);
    await verificaInvariante();
  });

  it('test_se_puede_usar_todo_el_stock_y_la_refaccion_queda_agotada', async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 10 });

    expect(res.status).toBe(201);
    expect(res.body.data.part).toMatchObject({ stock: 0, stockStatus: 'AGOTADO' });
  });

  it('test_rechaza_una_cantidad_mayor_al_stock_sin_cambiar_nada', async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 11 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
    expect(res.body.error.details).toEqual({ available: 10, requested: 11 });
    expect(res.body.error.message).toContain('10');
    expect(await stockDe()).toBe(10);
    expect(await lineas()).toEqual([]);
    expect(await movimientos()).toHaveLength(1);
  });

  it.each([0, -1, 1.5, '2', null, 100001])('test_rechaza_la_cantidad_%p_con_400', async (cantidad) => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: cantidad });

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('quantity');
    expect(await stockDe()).toBe(10);
  });

  it('test_agregar_la_misma_refaccion_suma_sobre_una_sola_linea', async () => {
    await agregar(mecanico, { partId: parte.id, quantity: 2 });

    const res = await agregar(mecanico, { partId: parte.id, quantity: 3 });

    expect(res.status).toBe(201);
    expect(res.body.data.item.quantity).toBe(5);
    expect(await lineas()).toEqual([{ partId: parte.id, quantity: 5 }]);
    expect(await stockDe()).toBe(5);
    expect(await movimientos()).toHaveLength(3);
    await verificaInvariante();
  });

  it('test_una_refaccion_inactiva_no_se_puede_usar', async () => {
    await query('UPDATE parts SET active = 0 WHERE id = ?', [parte.id]);

    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PART_INACTIVE');
    expect(await stockDe()).toBe(10);
  });

  it('test_una_refaccion_inexistente_responde_404', async () => {
    const res = await agregar(mecanico, { partId: 999999, quantity: 1 });

    expect(res.status).toBe(404);
  });

  it('test_la_orden_terminada_todavia_permite_agregar_para_corregir_omisiones', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPA-TER-B' });
    const terminada = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'TERMINADO' });

    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 }, terminada.id);

    expect(res.status).toBe(201);
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'ESPERANDO_REFACCION'])('test_la_orden_en_estado_%s_permite_agregar', async (estado) => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: `OPA-${estado.slice(0, 3)}-C` });
    const abierta = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: estado });

    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 }, abierta.id);

    expect(res.status).toBe(201);
  });

  it('test_la_orden_entregada_es_de_solo_lectura', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPA-ENT-D' });
    const entregada = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO' });

    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 }, entregada.id);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
    expect(await stockDe()).toBe(10);
  });

  it('test_el_detalle_de_la_orden_incluye_las_refacciones_para_todos_los_roles', async () => {
    await agregar(mecanico, { partId: parte.id, quantity: 2 });

    for (const user of [admin, recepcion, mecanico]) {
      const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(user.token));
      expect(res.status).toBe(200);
      expect(res.body.data.parts).toEqual([
        { id: expect.any(Number), partId: parte.id, code: 'OPA-REF', name: 'Balatas', unit: 'pieza', quantity: 2 },
      ]);
    }
  });
});

describe('corregir la cantidad de una refacción', () => {
  let linea;

  beforeEach(async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 4 });
    linea = res.body.data.item;
  });

  it('test_aumentar_genera_una_salida_por_la_diferencia', async () => {
    const res = await corregir(mecanico, linea.id, 6);

    expect(res.status).toBe(200);
    expect(res.body.data.item.quantity).toBe(6);
    expect(await stockDe()).toBe(4);
    expect((await movimientos()).slice(-1)[0]).toMatchObject({ type: 'OUT', quantity: -2 });
    await verificaInvariante();
  });

  it('test_aumentar_mas_alla_del_stock_se_rechaza_sin_cambios', async () => {
    const res = await corregir(mecanico, linea.id, 4 + 7);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
    expect(res.body.error.details).toEqual({ available: 6, requested: 7 });
    expect(await stockDe()).toBe(6);
    expect((await lineas())[0].quantity).toBe(4);
  });

  it('test_disminuir_devuelve_la_diferencia_con_una_entrada', async () => {
    const res = await corregir(mecanico, linea.id, 1);

    expect(res.status).toBe(200);
    expect(res.body.data.item.quantity).toBe(1);
    expect(await stockDe()).toBe(9);
    expect((await movimientos()).slice(-1)[0]).toMatchObject({ type: 'IN', quantity: 3, orderId: orden.id });
    await verificaInvariante();
  });

  it('test_la_misma_cantidad_no_genera_movimientos', async () => {
    const antes = (await movimientos()).length;

    const res = await corregir(mecanico, linea.id, 4);

    expect(res.status).toBe(200);
    expect((await movimientos()).length).toBe(antes);
  });

  it('test_rechaza_cantidades_invalidas_y_lineas_inexistentes', async () => {
    expect((await corregir(mecanico, linea.id, 0)).status).toBe(400);
    expect((await corregir(mecanico, linea.id, 2.5)).status).toBe(400);
    expect((await corregir(mecanico, 999999, 2)).status).toBe(404);
    expect(await stockDe()).toBe(6);
  });

  it('test_una_refaccion_desactivada_permite_devolver_pero_no_aumentar', async () => {
    await query('UPDATE parts SET active = 0 WHERE id = ?', [parte.id]);

    const aumentar = await corregir(mecanico, linea.id, 5);
    const disminuir = await corregir(mecanico, linea.id, 2);

    expect(aumentar.status).toBe(409);
    expect(aumentar.body.error.code).toBe('PART_INACTIVE');
    expect(disminuir.status).toBe(200);
    expect(await stockDe()).toBe(8);
  });

  it('test_una_linea_de_otra_orden_no_se_puede_corregir_desde_esta', async () => {
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPA-OTR-E' });
    const otra = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'DIAGNOSTICO' });

    const res = await corregir(mecanico, linea.id, 2, otra.id);

    expect(res.status).toBe(404);
  });
});

describe('quitar una refacción de la orden', () => {
  let linea;

  beforeEach(async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 4 });
    linea = res.body.data.item;
  });

  it('test_quitar_devuelve_la_cantidad_y_elimina_la_linea', async () => {
    const res = await quitar(mecanico, linea.id);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ deleted: true, part: { stock: 10 } });
    expect(await lineas()).toEqual([]);
    expect(await stockDe()).toBe(10);
    const ultimo = (await movimientos()).slice(-1)[0];
    expect(ultimo).toMatchObject({ type: 'IN', quantity: 4, orderId: orden.id });
    expect(ultimo.reason).toContain('Devolución');
    await verificaInvariante();
  });

  it('test_los_movimientos_se_conservan_aunque_se_quite_la_linea', async () => {
    await quitar(mecanico, linea.id);

    expect(await movimientos()).toHaveLength(3);
  });

  it('test_quitar_una_linea_inexistente_responde_404', async () => {
    expect((await quitar(mecanico, 999999)).status).toBe(404);
  });

  it('test_la_orden_entregada_no_permite_quitar_ni_corregir', async () => {
    await query("UPDATE service_orders SET status = 'ENTREGADO' WHERE id = ?", [orden.id]);

    const quita = await quitar(mecanico, linea.id);
    const corrige = await corregir(mecanico, linea.id, 1);

    expect(quita.status).toBe(409);
    expect(quita.body.error.code).toBe('ORDER_READ_ONLY');
    expect(corrige.body.error.code).toBe('ORDER_READ_ONLY');
    expect(await lineas()).toEqual([{ partId: parte.id, quantity: 4 }]);
  });
});

describe('permisos (SC-008)', () => {
  it('test_un_mecanico_no_asignado_recibe_404_en_las_tres_operaciones', async () => {
    const creada = await agregar(mecanico, { partId: parte.id, quantity: 1 });
    const lineId = creada.body.data.item.id;

    expect((await agregar(otroMecanico, { partId: parte.id, quantity: 1 })).status).toBe(404);
    expect((await corregir(otroMecanico, lineId, 2)).status).toBe(404);
    expect((await quitar(otroMecanico, lineId)).status).toBe(404);
    expect(await stockDe()).toBe(9);
  });

  it('test_recepcion_recibe_403_en_las_tres_operaciones', async () => {
    const creada = await agregar(mecanico, { partId: parte.id, quantity: 1 });
    const lineId = creada.body.data.item.id;

    expect((await agregar(recepcion, { partId: parte.id, quantity: 1 })).status).toBe(403);
    expect((await corregir(recepcion, lineId, 2)).status).toBe(403);
    expect((await quitar(recepcion, lineId)).status).toBe(403);
    expect(await stockDe()).toBe(9);
  });

  it('test_el_administrador_puede_modificar_cualquier_orden', async () => {
    const res = await agregar(admin, { partId: parte.id, quantity: 2 });

    expect(res.status).toBe(201);
    expect((await movimientos()).slice(-1)[0]).toMatchObject({ type: 'OUT', quantity: -2 });
  });

  it('test_exige_sesion_y_una_orden_existente', async () => {
    expect((await request(app).post(`/api/orders/${orden.id}/parts`).send({ partId: parte.id, quantity: 1 })).status).toBe(401);
    expect((await agregar(admin, { partId: parte.id, quantity: 1 }, 999999)).status).toBe(404);
  });
});
