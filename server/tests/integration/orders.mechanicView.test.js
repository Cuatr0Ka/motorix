import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
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
let otroMecanico;
let orden;
let parte;

const detalle = (user, id = orden.id) => request(app).get(`/api/orders/${id}`).set(auth(user.token));

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'MVW-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  await createService(orden.id, { description: 'Cambio de balatas', amount: '850.00' });
  await createLabor(orden.id, { description: 'Mano de obra', amount: '400.50' });
  parte = await createPart(admin.id, { code: 'MVW-REF', name: 'Balatas', stock: 10, purchasePrice: 60, salePrice: 180 });
  await createOrderPart(orden.id, parte.id, mecanico.id, 2, '180.00');
});

describe('detalle de la orden para el mecánico (FR-014)', () => {
  it('test_las_lineas_de_refaccion_solo_traen_id_refaccion_codigo_nombre_unidad_y_cantidad', async () => {
    const res = await detalle(mecanico);

    expect(res.status).toBe(200);
    expect(res.body.data.parts).toHaveLength(1);
    expect(Object.keys(res.body.data.parts[0]).sort()).toEqual(['code', 'id', 'name', 'partId', 'quantity', 'unit']);
  });

  it('test_los_totales_suman_solo_servicios_y_mano_de_obra_y_no_traen_el_campo_de_refacciones', async () => {
    const { totals } = (await detalle(mecanico)).body.data;

    expect(Object.keys(totals).sort()).toEqual(['labor', 'services', 'total']);
    expect(totals).toEqual({ services: '850.00', labor: '400.50', total: '1250.50' });
  });

  it('test_no_recibe_el_bloque_de_cobro_ni_ningun_desglose', async () => {
    const data = (await detalle(mecanico)).body.data;

    expect(data).not.toHaveProperty('billing');
    expect(JSON.stringify(data)).not.toMatch(/breakdown|amountDifference|unitPrice|salePrice|purchasePrice/);
  });

  it('test_el_precio_de_la_refaccion_no_aparece_en_ninguna_parte_de_la_respuesta', async () => {
    const texto = JSON.stringify((await detalle(mecanico)).body);

    expect(texto).not.toContain('180.00');
    expect(texto).not.toContain('360.00');
    expect(texto).not.toContain('60.00');
  });

  it('test_el_listado_de_ordenes_del_mecanico_tampoco_lleva_precios_de_refacciones', async () => {
    const res = await request(app).get('/api/orders').set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(JSON.stringify(res.body)).not.toMatch(/unitPrice|salePrice|purchasePrice|breakdown|"parts"/);
  });

  it('test_otro_mecanico_no_puede_ver_la_orden_ni_sus_lineas', async () => {
    const res = await detalle(otroMecanico);

    expect(res.status).toBe(404);
    expect(JSON.stringify(res.body)).not.toContain('MVW-REF');
  });
});

describe('respuestas de servicios y mano de obra para el mecánico', () => {
  it('test_agregar_un_servicio_devuelve_totales_sin_el_campo_de_refacciones', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/services`).set(auth(mecanico.token)).send({ description: 'Revisión', amount: 100 });

    expect(res.status).toBe(201);
    expect(res.body.data.totals).toEqual({ services: '950.00', labor: '400.50', total: '1350.50' });
    expect(res.body.data.totals).not.toHaveProperty('parts');
  });

  it('test_corregir_y_quitar_una_linea_de_mano_de_obra_tambien_omiten_las_refacciones', async () => {
    const [{ id: lineaId }] = (await detalle(mecanico)).body.data.labor;

    const cambio = await request(app).patch(`/api/orders/${orden.id}/labor/${lineaId}`).set(auth(mecanico.token)).send({ amount: 500 });
    const baja = await request(app).delete(`/api/orders/${orden.id}/labor/${lineaId}`).set(auth(mecanico.token));

    expect(cambio.status).toBe(200);
    expect(cambio.body.data.totals).toEqual({ services: '850.00', labor: '500.00', total: '1350.00' });
    expect(baja.status).toBe(200);
    expect(baja.body.data.totals).toEqual({ services: '850.00', labor: '0.00', total: '850.00' });
    expect(baja.body.data.totals).not.toHaveProperty('parts');
  });

  it('test_las_mismas_operaciones_del_administrador_si_devuelven_el_subtotal_de_refacciones', async () => {
    const res = await request(app).post(`/api/orders/${orden.id}/services`).set(auth(admin.token)).send({ description: 'Revisión', amount: 100 });

    expect(res.status).toBe(201);
    expect(res.body.data.totals).toEqual({ services: '950.00', labor: '400.50', parts: '360.00', total: '1710.50' });
  });
});

describe('detalle de la orden para recepción y administración', () => {
  it.each([
    ['recepción', () => recepcion],
    ['administrador', () => admin],
  ])('test_%s_recibe_precio_importe_y_totales_con_refacciones', async (_nombre, quien) => {
    const data = (await detalle(quien())).body.data;

    expect(data.parts[0]).toMatchObject({ code: 'MVW-REF', quantity: 2, unitPrice: '180.00', amount: '360.00', legacy: false });
    expect(data.totals).toEqual({ services: '850.00', labor: '400.50', parts: '360.00', total: '1610.50' });
    expect(data.billing.total).toBe('1610.50');
  });

  it('test_recepcion_nunca_recibe_el_precio_de_compra_aunque_si_el_de_venta', async () => {
    const texto = JSON.stringify((await detalle(recepcion)).body);

    expect(texto).toContain('180.00');
    expect(texto).not.toMatch(/purchasePrice|purchase_price/);
    expect(texto).not.toContain('"60.00"');
  });

  it('test_el_administrador_recibe_el_mismo_detalle_de_la_orden_que_recepcion_sin_el_precio_de_compra', async () => {
    const deAdmin = (await detalle(admin)).body.data;
    const deRecepcion = (await detalle(recepcion)).body.data;

    expect(deAdmin.parts).toEqual(deRecepcion.parts);
    expect(deAdmin.totals).toEqual(deRecepcion.totals);
    expect(deAdmin.billing.breakdown).toEqual(deRecepcion.billing.breakdown);
  });
});
