import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createLabor,
  createOrder,
  createOrderPart,
  createPart,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;
let parte;

const agregar = (user, cuerpo, id = orden.id) => request(app).post(`/api/orders/${id}/parts`).set(auth(user.token)).send(cuerpo);
const corregir = (user, lineId, cantidad, id = orden.id) =>
  request(app).patch(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token)).send({ quantity: cantidad });
const quitar = (user, lineId, id = orden.id) => request(app).delete(`/api/orders/${id}/parts/${lineId}`).set(auth(user.token));
const detalle = (user = admin, id = orden.id) => request(app).get(`/api/orders/${id}`).set(auth(user.token));
const cambiarPrecio = (id, precio) => request(app).patch(`/api/parts/${id}`).set(auth(admin.token)).send({ salePrice: precio });
const stockDe = async (id = parte.id) => (await query('SELECT stock FROM parts WHERE id = ?', [id]))[0].stock;
const movimientos = async (id = parte.id) => (await query('SELECT COUNT(*) AS n FROM inventory_movements WHERE part_id = ?', [id]))[0].n;
const lineasEnBase = (id = orden.id) => query('SELECT part_id AS partId, quantity, unit_price AS unitPrice FROM order_parts WHERE order_id = ?', [id]);

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPP-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  parte = await createPart(admin.id, { code: 'OPP-REF', name: 'Balatas', stock: 10, minStock: 3, purchasePrice: 120, salePrice: 180 });
});

describe('precio de la línea al agregar una refacción (FR-004)', () => {
  it('test_la_linea_guarda_el_precio_de_venta_vigente_al_agregarla', async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 2 });

    expect(res.status).toBe(201);
    expect(await lineasEnBase()).toEqual([{ partId: parte.id, quantity: 2, unitPrice: '180.00' }]);

    const vista = await detalle(admin);
    expect(vista.body.data.parts).toEqual([
      expect.objectContaining({ partId: parte.id, quantity: 2, unitPrice: '180.00', amount: '360.00', legacy: false }),
    ]);
  });

  it('test_un_cambio_posterior_del_precio_no_altera_la_linea_ni_el_total', async () => {
    await agregar(mecanico, { partId: parte.id, quantity: 2 });
    const antes = (await detalle(admin)).body.data;

    const cambio = await cambiarPrecio(parte.id, '250.00');
    const despues = (await detalle(admin)).body.data;

    expect(cambio.status).toBe(200);
    expect(despues.parts[0]).toMatchObject({ unitPrice: '180.00', amount: '360.00' });
    expect(despues.totals).toEqual(antes.totals);
    expect(despues.totals.parts).toBe('360.00');
  });

  it('test_agregar_de_nuevo_la_misma_refaccion_suma_la_cantidad_y_conserva_el_precio_guardado', async () => {
    await agregar(mecanico, { partId: parte.id, quantity: 2 });
    await cambiarPrecio(parte.id, '250.00');

    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(201);
    expect(await lineasEnBase()).toEqual([{ partId: parte.id, quantity: 3, unitPrice: '180.00' }]);
    expect((await detalle(admin)).body.data.parts[0]).toMatchObject({ quantity: 3, unitPrice: '180.00', amount: '540.00' });
  });

  it('test_una_linea_nueva_despues_del_cambio_de_precio_toma_el_precio_nuevo', async () => {
    const otra = await createPart(admin.id, { code: 'OPP-OTRA', stock: 5, salePrice: 80 });
    await agregar(mecanico, { partId: parte.id, quantity: 1 });
    await cambiarPrecio(otra.id, '95.50');

    await agregar(mecanico, { partId: otra.id, quantity: 2 });

    const lineas = await lineasEnBase();
    expect(lineas.find((l) => l.partId === otra.id).unitPrice).toBe('95.50');
    expect(lineas.find((l) => l.partId === parte.id).unitPrice).toBe('180.00');
  });

  it('test_el_precio_de_la_linea_nunca_cambia_al_corregir_su_cantidad', async () => {
    const alta = await agregar(admin, { partId: parte.id, quantity: 2 });
    await cambiarPrecio(parte.id, '999.00');

    const res = await corregir(admin, alta.body.data.item.id, 4);

    expect(res.status).toBe(200);
    expect(await lineasEnBase()).toEqual([{ partId: parte.id, quantity: 4, unitPrice: '180.00' }]);
  });
});

describe('refacción sin precio de venta (FR-020)', () => {
  it('test_responde_422_PART_PRICE_MISSING_y_no_crea_la_linea_ni_el_movimiento', async () => {
    const sinPrecio = await createPart(admin.id, { code: 'OPP-SIN', stock: 5, salePrice: null });
    const movimientosAntes = await movimientos(sinPrecio.id);

    const res = await agregar(mecanico, { partId: sinPrecio.id, quantity: 1 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PART_PRICE_MISSING');
    expect(res.body.error.message).toContain('administrador');
    expect(await lineasEnBase()).toEqual([]);
    expect(await stockDe(sinPrecio.id)).toBe(5);
    expect(await movimientos(sinPrecio.id)).toBe(movimientosAntes);
  });

  it('test_una_vez_capturado_el_precio_se_puede_agregar', async () => {
    const sinPrecio = await createPart(admin.id, { code: 'OPP-SIN', stock: 5, salePrice: null });
    expect((await agregar(mecanico, { partId: sinPrecio.id, quantity: 1 })).status).toBe(422);

    await cambiarPrecio(sinPrecio.id, '60.00');
    const res = await agregar(mecanico, { partId: sinPrecio.id, quantity: 1 });

    expect(res.status).toBe(201);
    expect(await lineasEnBase()).toEqual([{ partId: sinPrecio.id, quantity: 1, unitPrice: '60.00' }]);
  });
});

describe('línea anterior a los precios (FR-015, FR-024)', () => {
  let linea;

  beforeEach(async () => {
    linea = await createOrderPart(orden.id, parte.id, admin.id, 2);
  });

  it('test_la_linea_anterior_no_suma_al_total_y_se_marca_como_anterior', async () => {
    const vista = (await detalle(admin)).body.data;

    expect(vista.parts[0]).toMatchObject({ unitPrice: '0.00', amount: '0.00', legacy: true });
    expect(vista.totals).toEqual({ services: '0.00', labor: '0.00', parts: '0.00', total: '0.00' });
  });

  it('test_aumentar_la_cantidad_de_una_linea_anterior_responde_422_LEGACY_LINE_LOCKED', async () => {
    const stockAntes = await stockDe();

    const porPatch = await corregir(admin, linea.id, 3);
    const porAlta = await agregar(admin, { partId: parte.id, quantity: 1 });

    expect(porPatch.status).toBe(422);
    expect(porPatch.body.error.code).toBe('LEGACY_LINE_LOCKED');
    expect(porAlta.status).toBe(422);
    expect(porAlta.body.error.code).toBe('LEGACY_LINE_LOCKED');
    expect(await lineasEnBase()).toEqual([{ partId: parte.id, quantity: 2, unitPrice: '0.00' }]);
    expect(await stockDe()).toBe(stockAntes);
  });

  it('test_disminuir_o_quitar_una_linea_anterior_se_permite', async () => {
    const baja = await corregir(admin, linea.id, 1);
    const quita = await quitar(admin, linea.id);

    expect(baja.status).toBe(200);
    expect(baja.body.data.item).toMatchObject({ quantity: 1, unitPrice: '0.00' });
    expect(quita.status).toBe(200);
    expect(await lineasEnBase()).toEqual([]);
  });

  it('test_quitarla_y_volverla_a_agregar_toma_el_precio_vigente', async () => {
    await quitar(admin, linea.id);

    const res = await agregar(admin, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(201);
    expect(await lineasEnBase()).toEqual([{ partId: parte.id, quantity: 1, unitPrice: '180.00' }]);
  });
});

describe('total de la orden con refacciones (FR-005)', () => {
  it('test_el_total_suma_servicios_mano_de_obra_y_refacciones', async () => {
    await createService(orden.id, { amount: '850.00' });
    await createLabor(orden.id, { amount: '400.50' });
    await agregar(mecanico, { partId: parte.id, quantity: 2 });

    const totales = (await detalle(admin)).body.data.totals;

    expect(totales).toEqual({ services: '850.00', labor: '400.50', parts: '360.00', total: '1610.50' });
  });

  it('test_el_importe_de_las_lineas_tiene_dos_decimales_exactos', async () => {
    const barata = await createPart(admin.id, { code: 'OPP-CENT', stock: 10, salePrice: '0.10' });
    await agregar(admin, { partId: barata.id, quantity: 3 });
    await agregar(admin, { partId: parte.id, quantity: 3 });

    const vista = (await detalle(admin)).body.data;

    expect(vista.parts.map((p) => p.amount).sort()).toEqual(['0.30', '540.00']);
    expect(vista.totals.parts).toBe('540.30');
  });

  it('test_una_orden_con_solo_refacciones_con_precio_tiene_total_mayor_a_cero', async () => {
    await agregar(mecanico, { partId: parte.id, quantity: 1 });

    const totales = (await detalle(recepcion)).body.data.totals;

    expect(totales).toEqual({ services: '0.00', labor: '0.00', parts: '180.00', total: '180.00' });
  });

  it('test_quitar_una_linea_baja_el_total', async () => {
    const alta = await agregar(admin, { partId: parte.id, quantity: 2 });
    await quitar(admin, alta.body.data.item.id);

    expect((await detalle(admin)).body.data.totals.total).toBe('0.00');
  });
});

describe('tope del total de la orden (FR-022)', () => {
  it('test_acepta_una_linea_que_deja_el_total_exactamente_en_el_tope', async () => {
    const cara = await createPart(admin.id, { code: 'OPP-TOPE', stock: 5, salePrice: '9999999.99' });

    const res = await agregar(admin, { partId: cara.id, quantity: 1 });

    expect(res.status).toBe(201);
    expect((await detalle(admin)).body.data.totals.total).toBe('9999999.99');
  });

  it('test_rechaza_con_422_ORDER_TOTAL_LIMIT_la_linea_que_pasa_del_tope_y_no_cambia_stock_ni_lineas', async () => {
    await createService(orden.id, { amount: '9999900.00' });
    const stockAntes = await stockDe();
    const movimientosAntes = await movimientos();

    const res = await agregar(admin, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ORDER_TOTAL_LIMIT');
    expect(res.body.error.details).toEqual({ limit: '9999999.99' });
    expect(await lineasEnBase()).toEqual([]);
    expect(await stockDe()).toBe(stockAntes);
    expect(await movimientos()).toBe(movimientosAntes);
  });

  it('test_rechaza_aumentar_la_cantidad_de_una_linea_si_el_total_pasa_del_tope', async () => {
    const cara = await createPart(admin.id, { code: 'OPP-CARA', stock: 5, salePrice: '5000000.00' });
    const alta = await agregar(admin, { partId: cara.id, quantity: 1 });
    const stockAntes = await stockDe(cara.id);

    const res = await corregir(admin, alta.body.data.item.id, 2);

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ORDER_TOTAL_LIMIT');
    expect(await lineasEnBase()).toEqual([{ partId: cara.id, quantity: 1, unitPrice: '5000000.00' }]);
    expect(await stockDe(cara.id)).toBe(stockAntes);
  });

  it('test_disminuir_la_cantidad_siempre_se_permite_aunque_el_total_ya_este_en_el_tope', async () => {
    const cara = await createPart(admin.id, { code: 'OPP-CARA', stock: 5, salePrice: '4999999.99' });
    const alta = await agregar(admin, { partId: cara.id, quantity: 2 });

    const res = await corregir(admin, alta.body.data.item.id, 1);

    expect(res.status).toBe(200);
  });
});

describe('respuestas según el rol', () => {
  it('test_la_respuesta_de_agregar_incluye_precio_e_importe_para_el_administrador', async () => {
    const res = await agregar(admin, { partId: parte.id, quantity: 2 });

    expect(res.body.data.item).toMatchObject({ unitPrice: '180.00', amount: '360.00', legacy: false });
  });

  it('test_recepcion_no_modifica_las_refacciones_de_una_orden_pero_si_ve_sus_precios', async () => {
    const alta = await agregar(admin, { partId: parte.id, quantity: 1 });

    const agrega = await agregar(recepcion, { partId: parte.id, quantity: 1 });
    const corrige = await corregir(recepcion, alta.body.data.item.id, 2);
    const quita = await quitar(recepcion, alta.body.data.item.id);
    const vista = await detalle(recepcion);

    expect([agrega.status, corrige.status, quita.status]).toEqual([403, 403, 403]);
    expect(vista.body.data.parts[0]).toMatchObject({ unitPrice: '180.00', amount: '180.00', legacy: false });
    expect(vista.body.data.parts[0]).not.toHaveProperty('purchasePrice');
  });

  it('test_la_respuesta_de_agregar_para_el_mecanico_no_trae_ningun_precio', async () => {
    const res = await agregar(mecanico, { partId: parte.id, quantity: 1 });

    expect(res.status).toBe(201);
    for (const clave of ['unitPrice', 'amount', 'legacy']) expect(res.body.data.item).not.toHaveProperty(clave);
    for (const clave of ['purchasePrice', 'salePrice', 'priceMissing']) expect(res.body.data.part).not.toHaveProperty(clave);
  });
});
