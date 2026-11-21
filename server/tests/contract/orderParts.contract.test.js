import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createOrderPart,
  createPart,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;
let parte;

// Línea para el mecánico: sin ningún precio (FR-014).
const linea = {
  id: expect.any(Number),
  partId: expect.any(Number),
  code: expect.any(String),
  name: expect.any(String),
  unit: expect.any(String),
  quantity: expect.any(Number),
};

// Línea para administración y recepción: con precio unitario, importe y bandera de línea anterior (Sprint 5).
const lineaConPrecio = { ...linea, unitPrice: expect.any(String), amount: expect.any(String), legacy: expect.any(Boolean) };

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'OPC-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  parte = await createPart(admin.id, { code: 'OPC-REF', stock: 5, minStock: 3 });
});

describe('POST /api/orders/:id/parts (contrato)', () => {
  it('test_responde_201_con_la_linea_y_la_refaccion_actualizada', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });

    expect(res.status).toBe(201);
    expect(res.body.data.item).toEqual({ ...linea, quantity: 2 });
    expect(res.body.data.part).toMatchObject({ id: parte.id, stock: 3, stockStatus: 'BAJO' });
  });

  it('test_stock_insuficiente_responde_409_con_el_disponible', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 9 });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'INSUFFICIENT_STOCK', details: { available: 5, requested: 9 } });
  });

  it('test_un_cuerpo_invalido_responde_400_con_detalles_por_campo', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ quantity: 0 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['partId', 'quantity']);
  });
});

describe('PATCH y DELETE /api/orders/:id/parts/:lineId (contrato)', () => {
  let lineId;

  beforeEach(async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });
    lineId = res.body.data.item.id;
  });

  it('test_patch_responde_200_con_la_linea_corregida', async () => {
    const res = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(admin.token)).send({ quantity: 4 });

    expect(res.status).toBe(200);
    expect(res.body.data.item).toEqual({ ...lineaConPrecio, quantity: 4 });
    expect(res.body.data.part.stock).toBe(1);
  });

  it('test_delete_responde_200_con_deleted_y_la_refaccion', async () => {
    const res = await request(app).delete(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ deleted: true, part: { id: parte.id, stock: 5 } });
  });

  it('test_un_identificador_de_linea_invalido_responde_400', async () => {
    const res = await request(app).delete(`/api/orders/${orden.id}/parts/abc`).set(auth(mecanico.token));

    expect(res.status).toBe(400);
  });

  it('test_recepcion_recibe_403_y_sin_sesion_401', async () => {
    const sinPermiso = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).set(auth(recepcion.token)).send({ quantity: 1 });
    const sinSesion = await request(app).patch(`/api/orders/${orden.id}/parts/${lineId}`).send({ quantity: 1 });

    expect(sinPermiso.status).toBe(403);
    expect(sinSesion.status).toBe(401);
  });
});

describe('GET /api/orders/:id (contrato ampliado)', () => {
  it('test_incluye_parts_y_service_mileage_para_todos_los_roles', async () => {
    await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 1 });

    for (const user of [admin, recepcion, mecanico]) {
      const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(user.token));
      expect(res.status).toBe(200);
      expect(res.body.data.parts).toEqual([{ ...(user === mecanico ? linea : lineaConPrecio), quantity: 1 }]);
      expect(res.body.data).toHaveProperty('serviceMileage', null);
      expect(res.body.data).toHaveProperty('maintenance', null);
    }
  });
});

describe('precios en las líneas y los totales (Sprint 5, contrato)', () => {
  const dosDecimales = expect.stringMatching(/^\d+\.\d{2}$/);
  const lineaPrecio = { ...linea, unitPrice: dosDecimales, amount: dosDecimales, legacy: false };

  const agregarComo = (user, cuerpo = { partId: parte.id, quantity: 2 }) =>
    request(app).post(`/api/orders/${orden.id}/parts`).set(auth(user.token)).send(cuerpo);

  beforeEach(async () => {
    parte = await createPart(admin.id, { code: 'OPC-PRE', stock: 20, minStock: 3, purchasePrice: 60, salePrice: 100 });
  });

  it('test_el_administrador_recibe_la_linea_con_precio_unitario_e_importe', async () => {
    const porAdmin = await agregarComo(admin);

    expect(porAdmin.status).toBe(201);
    expect(porAdmin.body.data.item).toEqual({ ...lineaPrecio, quantity: 2, unitPrice: '100.00', amount: '200.00' });
  });

  it('test_recepcion_recibe_403_al_agregar_y_ve_la_linea_con_precio_en_el_detalle', async () => {
    const rechazado = await agregarComo(recepcion);
    await agregarComo(admin);
    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));

    expect(rechazado.status).toBe(403);
    expect(detalle.body.data.parts[0]).toEqual({ ...lineaPrecio, quantity: 2, unitPrice: '100.00', amount: '200.00' });
  });

  it('test_el_mecanico_recibe_la_linea_reducida_sin_precio_importe_ni_bandera', async () => {
    const res = await agregarComo(mecanico);

    expect(res.status).toBe(201);
    expect(res.body.data.item).toEqual({ ...linea, quantity: 2 });
  });

  it('test_la_refaccion_de_la_respuesta_solo_lleva_precios_para_el_administrador_y_no_para_el_mecanico', async () => {
    const porAdmin = await agregarComo(admin, { partId: parte.id, quantity: 1 });
    const porMecanico = await agregarComo(mecanico, { partId: parte.id, quantity: 1 });

    expect(porAdmin.body.data.part).toMatchObject({ purchasePrice: '60.00', salePrice: '100.00', priceMissing: false });
    for (const clave of ['purchasePrice', 'salePrice', 'priceMissing', 'category', 'brand']) {
      expect(porMecanico.body.data.part).not.toHaveProperty(clave);
    }
  });

  it('test_el_detalle_incluye_totales_con_refacciones_para_administracion_y_recepcion_y_sin_ellas_para_el_mecanico', async () => {
    await agregarComo(admin);

    for (const user of [admin, recepcion]) {
      const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(user.token));
      expect(res.body.data.totals).toEqual({ services: '0.00', labor: '0.00', parts: '200.00', total: '200.00' });
      expect(res.body.data.parts[0]).toMatchObject({ unitPrice: '100.00', amount: '200.00', legacy: false });
    }
    const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(mecanico.token));
    expect(res.body.data.totals).toEqual({ services: '0.00', labor: '0.00', total: '0.00' });
    expect(res.body.data.parts[0]).toEqual({ ...linea, quantity: 2 });
  });

  it('test_los_errores_nuevos_tienen_la_forma_del_contrato', async () => {
    const sinPrecio = await createPart(admin.id, { code: 'OPC-SIN', stock: 5, salePrice: null });
    const faltaPrecio = await agregarComo(admin, { partId: sinPrecio.id, quantity: 1 });
    expect(faltaPrecio.status).toBe(422);
    expect(faltaPrecio.body.error).toEqual({ code: 'PART_PRICE_MISSING', message: expect.any(String) });

    const cara = await createPart(admin.id, { code: 'OPC-CARA', stock: 5, salePrice: '9999999.99' });
    await agregarComo(admin, { partId: cara.id, quantity: 1 });
    const tope = await agregarComo(admin, { partId: parte.id, quantity: 1 });
    expect(tope.status).toBe(422);
    expect(tope.body.error).toEqual({ code: 'ORDER_TOTAL_LIMIT', message: expect.any(String), details: { limit: '9999999.99' } });
  });

  it('test_aumentar_una_linea_anterior_responde_422_con_LEGACY_LINE_LOCKED', async () => {
    const anterior = await createPart(admin.id, { code: 'OPC-ANT', stock: 5, salePrice: 10 });
    const lineaAnterior = await createOrderPart(orden.id, anterior.id, admin.id, 1);

    const res = await request(app).patch(`/api/orders/${orden.id}/parts/${lineaAnterior.id}`).set(auth(admin.token)).send({ quantity: 2 });

    expect(res.status).toBe(422);
    expect(res.body.error).toEqual({ code: 'LEGACY_LINE_LOCKED', message: expect.any(String) });
  });
});
