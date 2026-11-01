import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createOrder, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const agregar = (user, orden, parte, cantidad = 1) =>
  request(app).post(`/api/orders/${orden.id}/parts`).set(auth(user.token)).send({ partId: parte.id, quantity: cantidad });
const cambiarPrecio = (parte, precio) => request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ salePrice: precio });

async function nuevaOrden(placa) {
  const { vehicle } = await createClientWithVehicle({ licensePlate: placa });
  return createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('precio de venta que cambia mientras se agrega la refacción (FR-004)', () => {
  it('test_la_linea_toma_el_precio_anterior_o_el_nuevo_nunca_un_valor_intermedio', async () => {
    const vistos = new Set();

    for (let i = 0; i < 8; i += 1) {
      const orden = await nuevaOrden(`PRC-${String(i).padStart(3, '0')}-Z`);
      const parte = await createPart(admin.id, { code: `PRC-REF-${i}`, stock: 5, salePrice: 100 });

      const [alta, cambio] = await Promise.all([agregar(mecanico, orden, parte), cambiarPrecio(parte, '300.00')]);

      expect(alta.status).toBe(201);
      expect(cambio.status).toBe(200);
      const [linea] = await query('SELECT unit_price AS unitPrice FROM order_parts WHERE order_id = ?', [orden.id]);
      expect(['100.00', '300.00']).toContain(linea.unitPrice);
      vistos.add(linea.unitPrice);
    }

    expect(vistos.size).toBeGreaterThanOrEqual(1);
  });
});

describe('tope del total con solicitudes simultáneas (FR-022)', () => {
  it('test_dos_altas_que_juntas_pasarian_del_tope_dejan_una_sola_aceptada', async () => {
    const orden = await nuevaOrden('TOP-001-A');
    const a = await createPart(admin.id, { code: 'TOP-A', stock: 5, salePrice: '6000000.00' });
    const b = await createPart(admin.id, { code: 'TOP-B', stock: 5, salePrice: '6000000.00' });

    const [r1, r2] = await Promise.all([agregar(mecanico, orden, a), agregar(admin, orden, b)]);

    expect([r1.status, r2.status].sort()).toEqual([201, 422]);
    const rechazada = r1.status === 422 ? r1 : r2;
    expect(rechazada.body.error.code).toBe('ORDER_TOTAL_LIMIT');

    const [{ total }] = await query('SELECT SUM(quantity * unit_price) AS total FROM order_parts WHERE order_id = ?', [orden.id]);
    expect(Number(total)).toBeLessThanOrEqual(9999999.99);
    const [{ lineas }] = await query('SELECT COUNT(*) AS lineas FROM order_parts WHERE order_id = ?', [orden.id]);
    expect(Number(lineas)).toBe(1);
  });

  it('test_el_stock_de_la_refaccion_rechazada_no_cambia_y_sigue_siendo_la_suma_de_sus_movimientos', async () => {
    const orden = await nuevaOrden('TOP-002-A');
    const a = await createPart(admin.id, { code: 'TOP-C', stock: 5, salePrice: '6000000.00' });
    const b = await createPart(admin.id, { code: 'TOP-D', stock: 5, salePrice: '6000000.00' });

    await Promise.all([agregar(mecanico, orden, a), agregar(admin, orden, b)]);

    for (const parte of [a, b]) {
      const [{ stock }] = await query('SELECT stock FROM parts WHERE id = ?', [parte.id]);
      const [{ suma }] = await query('SELECT COALESCE(SUM(quantity), 0) AS suma FROM inventory_movements WHERE part_id = ?', [parte.id]);
      expect(Number(suma)).toBe(stock);
      expect([4, 5]).toContain(stock);
    }
    const [{ salidas }] = await query("SELECT COUNT(*) AS salidas FROM inventory_movements WHERE type = 'OUT' AND order_id = ?", [orden.id]);
    expect(Number(salidas)).toBe(1);
  });
});
