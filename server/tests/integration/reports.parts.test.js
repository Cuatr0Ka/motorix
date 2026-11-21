import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createMovement, createOrder, createOrderPart, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { DENTRO, PERIODO, nuevoVehiculo } from '../helpers/reports.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let vehiculo;

const pedir = (ruta, token = admin.token) => request(app).get(`/api/reports/${ruta}`).query(PERIODO).set(auth(token));

async function usar(parte, cantidad, precio, fecha = DENTRO) {
  const orden = await createOrder((await nuevoVehiculo()).id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
  const linea = await createOrderPart(orden.id, parte.id, mecanico.id, cantidad, precio);
  await query('UPDATE order_parts SET created_at = ? WHERE id = ?', [fecha, linea.id]);
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'REF-001-A' }));
});

describe('costo y margen de refacciones (US6, FR-021)', () => {
  it('test_calcula_unidades_ingreso_costo_margen_y_porcentaje', async () => {
    const parte = await createPart(admin.id, { name: 'Balatas', code: 'BAL-1', purchasePrice: '500.00', salePrice: '780.00' });
    await usar(parte, 2, 780);
    await usar(parte, 1, 780);

    const { data } = (await pedir('parts')).body;

    expect(data.items[0]).toEqual({
      partId: parte.id,
      code: 'BAL-1',
      name: 'Balatas',
      units: 3,
      revenue: '2340.00',
      cost: '1500.00',
      margin: '840.00',
      marginPercent: '35.90',
      noCost: false,
    });
    expect(data.totals).toEqual({ revenue: '2340.00', cost: '1500.00', margin: '840.00', marginPercent: '35.90', noCostLines: 0 });
  });

  it('test_una_refaccion_sin_precio_de_compra_es_sin_costo_y_no_entra_en_los_totales', async () => {
    const conCosto = await createPart(admin.id, { purchasePrice: '100.00', salePrice: '150.00' });
    const sinCosto = await createPart(admin.id, { purchasePrice: null, salePrice: '200.00' });
    const enCero = await createPart(admin.id, { purchasePrice: '0.00', salePrice: '300.00' });
    await usar(conCosto, 2, 150);
    await usar(sinCosto, 1, 200);
    await usar(enCero, 1, 300);

    const { data } = (await pedir('parts')).body;
    const filaSin = data.items.find((i) => i.partId === sinCosto.id);

    expect(filaSin).toMatchObject({ noCost: true, cost: null, margin: null, marginPercent: null, revenue: '200.00' });
    expect(data.items.find((i) => i.partId === enCero.id).noCost).toBe(true);
    expect(data.totals).toMatchObject({ cost: '200.00', margin: '100.00', noCostLines: 2, revenue: '800.00' });
  });

  it('test_las_lineas_anteriores_al_sprint_5_con_precio_cero_no_distorsionan', async () => {
    const parte = await createPart(admin.id, { purchasePrice: '100.00' });
    await usar(parte, 5, 0);

    const { data } = (await pedir('parts')).body;

    expect(data.items).toEqual([]);
    expect(data.totals).toMatchObject({ revenue: '0.00', cost: '0.00', margin: '0.00' });
  });

  it('test_los_totales_son_la_suma_de_las_filas', async () => {
    const a = await createPart(admin.id, { purchasePrice: '10.10', salePrice: '20.20' });
    const b = await createPart(admin.id, { purchasePrice: '5.05', salePrice: '9.99' });
    await usar(a, 3, 20.2);
    await usar(b, 7, 9.99);

    const { data } = (await pedir('parts')).body;
    const suma = (clave) => data.items.reduce((t, i) => t + Math.round(Number(i[clave]) * 100), 0);

    expect(Math.round(Number(data.totals.revenue) * 100)).toBe(suma('revenue'));
    expect(Math.round(Number(data.totals.cost) * 100)).toBe(suma('cost'));
    expect(Math.round(Number(data.totals.margin) * 100)).toBe(suma('margin'));
  });
});

describe('rotación del inventario (US6, FR-021)', () => {
  it('test_calcula_salidas_existencia_inicial_y_final_promedio_y_rotacion', async () => {
    const parte = await createPart(admin.id, { stock: 0, name: 'Filtro', code: 'FIL-1' });
    // Entrada de 20 antes del periodo, salidas de 12 dentro y una entrada de 5 después.
    await query("INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by, created_at) VALUES (?, 'IN', 20, 'Compra', ?, '2026-09-20 10:00:00')", [parte.id, admin.id]);
    await query("INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by, created_at) VALUES (?, 'OUT', -7, 'Uso', ?, '2026-10-10 10:00:00')", [parte.id, admin.id]);
    await query("INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by, created_at) VALUES (?, 'OUT', -5, 'Uso', ?, '2026-10-20 10:00:00')", [parte.id, admin.id]);
    await query("INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by, created_at) VALUES (?, 'IN', 5, 'Compra', ?, '2026-11-05 10:00:00')", [parte.id, admin.id]);
    await query('UPDATE parts SET stock = 13 WHERE id = ?', [parte.id]);

    const { data } = (await pedir('rotation')).body;

    expect(data.items).toEqual([{ partId: parte.id, code: 'FIL-1', name: 'Filtro', out: 12, stockStart: 20, stockEnd: 8, averageStock: '14.00', rotation: '0.86' }]);
  });

  it('test_una_refaccion_sin_salidas_en_el_periodo_no_aparece_y_el_promedio_cero_da_rotacion_nula', async () => {
    const sinSalidas = await createPart(admin.id, { stock: 5 });
    await createMovement(sinSalidas.id, admin.id, { type: 'IN', quantity: 3 });
    expect((await pedir('rotation')).body.data.items).toEqual([]);

    const agotada = await createPart(admin.id, { stock: 0 });
    await query("INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by, created_at) VALUES (?, 'OUT', -4, 'Uso', ?, '2026-10-10 10:00:00')", [agotada.id, admin.id]);
    await query('UPDATE parts SET stock = 0 WHERE id = ?', [agotada.id]);
    const fila = (await pedir('rotation')).body.data.items.find((i) => i.partId === agotada.id);

    expect(fila).toMatchObject({ out: 4, stockStart: 4, stockEnd: 0, averageStock: '2.00', rotation: '2.00' });
  });
});

describe('permisos de los reportes de refacciones', () => {
  it('test_recepcion_y_mecanico_reciben_403_y_nunca_un_precio_de_compra', async () => {
    for (const ruta of ['parts', 'rotation']) {
      for (const u of [recepcion, mecanico]) {
        const res = await pedir(ruta, u.token);
        expect(res.status).toBe(403);
        expect(JSON.stringify(res.body)).not.toMatch(/purchase/i);
      }
    }
  });
});
