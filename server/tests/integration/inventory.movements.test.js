import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let parte;

const mover = (cuerpo, user = admin, id = parte.id) =>
  request(app).post(`/api/parts/${id}/movements`).set(auth(user.token)).send(cuerpo);
const stockActual = async (id = parte.id) => (await query('SELECT stock FROM parts WHERE id = ?', [id]))[0].stock;

/** Invariante del modelo: el stock de cada refacción es la suma de sus movimientos (SC-006). */
async function verificaInvariante() {
  const filas = await query(
    `SELECT p.id, p.stock, COALESCE(SUM(m.quantity), 0) AS suma
       FROM parts p LEFT JOIN inventory_movements m ON m.part_id = p.id GROUP BY p.id, p.stock`,
  );
  for (const fila of filas) expect(Number(fila.suma)).toBe(fila.stock);
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  parte = await createPart(admin.id, { code: 'MOV-001', stock: 10, minStock: 3 });
});

describe('entradas de mercancía (US3)', () => {
  it('test_la_entrada_aumenta_el_stock_y_registra_el_movimiento', async () => {
    const res = await mover({ type: 'IN', quantity: 5, reason: 'Compra a proveedor' });

    expect(res.status).toBe(201);
    expect(res.body.data.part).toMatchObject({ id: parte.id, stock: 15 });
    expect(res.body.data.movement).toMatchObject({
      type: 'IN',
      quantity: 5,
      reason: 'Compra a proveedor',
      order: null,
      createdBy: { id: admin.id },
    });
    expect(await stockActual()).toBe(15);
    await verificaInvariante();
  });

  it('test_la_entrada_sin_motivo_usa_un_motivo_por_defecto', async () => {
    const res = await mover({ type: 'IN', quantity: 1 });

    expect(res.body.data.movement.reason).toBe('Entrada de mercancía');
  });

  it('test_una_entrada_a_una_refaccion_inactiva_se_rechaza', async () => {
    await query('UPDATE parts SET active = 0 WHERE id = ?', [parte.id]);

    const res = await mover({ type: 'IN', quantity: 1 });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PART_INACTIVE');
    expect(await stockActual()).toBe(10);
  });

  it.each([0, -3, 2.5, '4', 100001])('test_rechaza_la_cantidad_%p_en_una_entrada', async (cantidad) => {
    const res = await mover({ type: 'IN', quantity: cantidad });

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain('quantity');
    expect(await stockActual()).toBe(10);
  });

  it('test_una_refaccion_inexistente_responde_404', async () => {
    const res = await mover({ type: 'IN', quantity: 1 }, admin, 999999);

    expect(res.status).toBe(404);
  });
});

describe('ajuste por conteo físico (aclaración 5)', () => {
  it('test_el_stock_queda_en_lo_contado_y_el_movimiento_guarda_la_diferencia_negativa', async () => {
    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: 7, reason: 'Conteo físico de octubre' });

    expect(res.status).toBe(201);
    expect(res.body.data.part.stock).toBe(7);
    expect(res.body.data.movement).toMatchObject({ type: 'ADJUSTMENT', quantity: -3, reason: 'Conteo físico de octubre' });
    await verificaInvariante();
  });

  it('test_un_conteo_mayor_guarda_la_diferencia_positiva', async () => {
    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: 12, reason: 'Se encontraron piezas' });

    expect(res.body.data.movement.quantity).toBe(2);
    expect(await stockActual()).toBe(12);
  });

  it('test_se_puede_ajustar_a_cero', async () => {
    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: 0, reason: 'Merma total' });

    expect(res.status).toBe(201);
    expect(res.body.data.part).toMatchObject({ stock: 0, stockStatus: 'AGOTADO' });
    await verificaInvariante();
  });

  it('test_un_conteo_igual_al_stock_actual_se_rechaza', async () => {
    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: 10, reason: 'Sin diferencia' });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('NO_ADJUSTMENT_DIFFERENCE');
  });

  it.each([-1, 2.5, '5', null])('test_rechaza_la_cantidad_contada_%p', async (contada) => {
    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: contada, reason: 'Conteo físico' });

    expect(res.status).toBe(400);
    expect(await stockActual()).toBe(10);
  });

  it('test_exige_un_motivo_de_al_menos_cinco_caracteres', async () => {
    const corto = await mover({ type: 'ADJUSTMENT', countedQuantity: 5, reason: 'abc' });
    const faltante = await mover({ type: 'ADJUSTMENT', countedQuantity: 5 });

    expect(corto.status).toBe(400);
    expect(faltante.status).toBe(400);
    expect(corto.body.error.details.map((d) => d.field)).toContain('reason');
  });

  it('test_un_ajuste_a_una_refaccion_inactiva_si_se_permite_para_corregir_el_conteo', async () => {
    await query('UPDATE parts SET active = 0 WHERE id = ?', [parte.id]);

    const res = await mover({ type: 'ADJUSTMENT', countedQuantity: 4, reason: 'Inventario de cierre' });

    expect(res.status).toBe(201);
  });
});

describe('tipos y permisos', () => {
  it('test_el_tipo_salida_no_se_acepta_por_esta_via', async () => {
    const res = await mover({ type: 'OUT', quantity: 1 });

    expect(res.status).toBe(400);
    expect(await stockActual()).toBe(10);
  });

  it('test_un_tipo_desconocido_o_ausente_se_rechaza', async () => {
    expect((await mover({ type: 'XYZ', quantity: 1 })).status).toBe(400);
    expect((await mover({ quantity: 1 })).status).toBe(400);
  });

  it.each(['mecanico', 'recepcion'])('test_el_rol_%s_no_puede_registrar_movimientos', async (rol) => {
    const user = rol === 'mecanico' ? mecanico : recepcion;

    const res = await mover({ type: 'IN', quantity: 1 }, user);

    expect(res.status).toBe(403);
    expect(await stockActual()).toBe(10);
  });
});

describe('historial de movimientos', () => {
  it('test_lista_los_movimientos_del_mas_reciente_al_mas_antiguo_con_paginacion', async () => {
    await mover({ type: 'IN', quantity: 5, reason: 'Compra' });
    await mover({ type: 'ADJUSTMENT', countedQuantity: 8, reason: 'Conteo físico' });

    const completa = await request(app).get(`/api/parts/${parte.id}/movements`).set(auth(admin.token));
    const pagina = await request(app).get(`/api/parts/${parte.id}/movements?page=2&pageSize=2`).set(auth(admin.token));

    expect(completa.status).toBe(200);
    expect(completa.body.data.map((m) => m.type)).toEqual(['ADJUSTMENT', 'IN', 'IN']);
    expect(completa.body.data.map((m) => m.quantity)).toEqual([-7, 5, 10]);
    expect(completa.body.meta).toEqual({ page: 1, pageSize: 20, total: 3 });
    expect(pagina.body.data).toHaveLength(1);
    await verificaInvariante();
  });

  it('test_solo_el_administrador_consulta_los_movimientos', async () => {
    const mec = await request(app).get(`/api/parts/${parte.id}/movements`).set(auth(mecanico.token));
    const inexistente = await request(app).get('/api/parts/999999/movements').set(auth(admin.token));

    expect(mec.status).toBe(403);
    expect(inexistente.status).toBe(404);
  });

  it('test_no_existen_rutas_para_editar_ni_borrar_movimientos', async () => {
    const [{ id }] = await query('SELECT id FROM inventory_movements LIMIT 1');

    const borrar = await request(app).delete(`/api/parts/${parte.id}/movements/${id}`).set(auth(admin.token));
    const editar = await request(app).patch(`/api/parts/${parte.id}/movements/${id}`).set(auth(admin.token)).send({ quantity: 1 });

    expect(borrar.status).toBe(404);
    expect(editar.status).toBe(404);
  });

  it('test_la_base_rechaza_un_movimiento_con_el_signo_incorrecto', async () => {
    await expect(
      query("INSERT INTO inventory_movements (part_id, type, quantity, created_by) VALUES (?, 'OUT', 3, ?)", [parte.id, admin.id]),
    ).rejects.toThrow();
    await expect(
      query("INSERT INTO inventory_movements (part_id, type, quantity, created_by) VALUES (?, 'ADJUSTMENT', 0, ?)", [parte.id, admin.id]),
    ).rejects.toThrow();
  });

  it('test_la_base_rechaza_un_stock_negativo', async () => {
    await expect(query('UPDATE parts SET stock = stock - 11 WHERE id = ?', [parte.id])).rejects.toThrow();
    expect(await stockActual()).toBe(10);
  });
});
