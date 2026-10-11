import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createPart,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const alertas = (user = admin) => request(app).get('/api/parts/alerts').set(auth(user.token));
const codigos = (res) => res.body.data.items.map((p) => p.code);

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('alertas de stock bajo (US6, CA-7)', () => {
  it('test_lista_las_refacciones_en_o_bajo_el_minimo_y_cuenta_las_agotadas', async () => {
    await createPart(admin.id, { code: 'SUF-001', name: 'Suficiente', stock: 10, minStock: 3 });
    await createPart(admin.id, { code: 'BAJ-002', name: 'Baja', stock: 2, minStock: 5 });
    await createPart(admin.id, { code: 'MIN-003', name: 'En el mínimo', stock: 3, minStock: 3 });
    await createPart(admin.id, { code: 'AGO-004', name: 'Agotada', stock: 0, minStock: 2 });

    const res = await alertas();

    expect(res.status).toBe(200);
    expect(res.body.data.count).toBe(3);
    expect(res.body.data.outOfStock).toBe(1);
    expect(codigos(res)).toEqual(['AGO-004', 'BAJ-002', 'MIN-003']);
    expect(res.body.data.items[0]).toMatchObject({ stock: 0, minStock: 2, stockStatus: 'AGOTADO' });
    expect(res.body.data.items[1]).toMatchObject({ stock: 2, minStock: 5, stockStatus: 'BAJO' });
  });

  it('test_con_minimo_cero_solo_alerta_al_llegar_a_cero', async () => {
    await createPart(admin.id, { code: 'CER-001', stock: 1, minStock: 0 });
    await createPart(admin.id, { code: 'CER-002', stock: 0, minStock: 0 });

    const res = await alertas();

    expect(codigos(res)).toEqual(['CER-002']);
  });

  it('test_las_refacciones_inactivas_no_generan_alertas', async () => {
    await createPart(admin.id, { code: 'INA-001', stock: 0, minStock: 5, active: 0 });

    const res = await alertas();

    expect(res.body.data).toEqual({ count: 0, outOfStock: 0, items: [] });
  });

  it('test_sin_alertas_devuelve_una_lista_vacia', async () => {
    await createPart(admin.id, { stock: 50, minStock: 3 });

    const res = await alertas();

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ count: 0, outOfStock: 0, items: [] });
  });

  it('test_una_salida_por_uso_en_una_orden_agrega_la_alerta_y_una_entrada_la_quita', async () => {
    const parte = await createPart(admin.id, { code: 'USO-001', stock: 5, minStock: 3 });
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'ALR-001-A' });
    const orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
    expect(codigos(await alertas())).toEqual([]);

    const uso = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });
    expect(uso.status).toBe(201);
    const conAlerta = await alertas();
    expect(codigos(conAlerta)).toEqual(['USO-001']);
    expect(conAlerta.body.data.items[0]).toMatchObject({ stock: 3, stockStatus: 'BAJO' });

    const entrada = await request(app).post(`/api/parts/${parte.id}/movements`).set(auth(admin.token)).send({ type: 'IN', quantity: 10 });
    expect(entrada.status).toBe(201);
    expect(codigos(await alertas())).toEqual([]);
  });

  it('test_agotar_la_refaccion_la_marca_como_agotada_en_las_alertas', async () => {
    const parte = await createPart(admin.id, { code: 'AGT-001', stock: 2, minStock: 3 });
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'ALR-002-B' });
    const orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });

    await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: parte.id, quantity: 2 });
    const res = await alertas();

    expect(res.body.data).toMatchObject({ count: 1, outOfStock: 1 });
    expect(res.body.data.items[0].stockStatus).toBe('AGOTADO');
  });

  it('test_desactivar_una_refaccion_con_alerta_la_quita_de_la_lista', async () => {
    const parte = await createPart(admin.id, { code: 'DES-001', stock: 0, minStock: 3 });
    expect(codigos(await alertas())).toEqual(['DES-001']);

    await request(app).patch(`/api/parts/${parte.id}`).set(auth(admin.token)).send({ active: false });

    expect(codigos(await alertas())).toEqual([]);
  });

  it.each(['mecanico', 'recepcion'])('test_el_rol_%s_recibe_403', async (rol) => {
    const res = await alertas(rol === 'mecanico' ? mecanico : recepcion);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_exige_sesion_y_alerts_no_se_confunde_con_un_identificador', async () => {
    const sinSesion = await request(app).get('/api/parts/alerts');

    expect(sinSesion.status).toBe(401);
    expect((await alertas()).status).toBe(200);
  });
});
