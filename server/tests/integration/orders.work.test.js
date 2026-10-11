import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createLabor,
  createOrder,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let mecanico;
let otroMecanico;
let orden;
let vehiculos;

const work = (id, body, user = mecanico) => request(app).patch(`/api/orders/${id}/work`).set(auth(user.token)).send(body);
const alta = (kind, id, body, user = mecanico) => request(app).post(`/api/orders/${id}/${kind}`).set(auth(user.token)).send(body);
const detalle = (id, user = recepcion) => request(app).get(`/api/orders/${id}`).set(auth(user.token));

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
  otroMecanico = await createUserWithToken('MECHANIC');
  vehiculos = [
    (await createClientWithVehicle({ licensePlate: 'WRK-100-A' })).vehicle,
    (await createClientWithVehicle({ licensePlate: 'WRK-200-B' })).vehicle,
  ];
  orden = await createOrder(vehiculos[0].id, recepcion.id, { mechanicId: mecanico.id, status: 'DIAGNOSTICO' });
});

describe('diagnóstico, observaciones y recomendaciones (US5, CA-4)', () => {
  it('test_el_mecanico_asignado_registra_y_luego_edita_el_diagnostico', async () => {
    await work(orden.id, { diagnosis: 'Falla en balatas' });
    const res = await work(orden.id, { diagnosis: 'Balatas y discos', recommendations: 'Revisar en 5 000 km' });

    expect(res.body.data).toMatchObject({ diagnosis: 'Balatas y discos', recommendations: 'Revisar en 5 000 km', observations: null });
    expect((await detalle(orden.id)).body.data.diagnosis).toBe('Balatas y discos');
  });

  it('test_un_texto_vacio_se_guarda_como_null_y_los_campos_no_enviados_no_cambian', async () => {
    await work(orden.id, { diagnosis: 'Algo', observations: 'Otra cosa' });

    const res = await work(orden.id, { diagnosis: '   ' });

    expect(res.body.data.diagnosis).toBeNull();
    expect(res.body.data.observations).toBe('Otra cosa');
  });

  it('test_lo_registrado_queda_visible_para_recepcion', async () => {
    await work(orden.id, { observations: 'Cliente pidió revisar luces', recommendations: 'Cambiar llantas' });

    const res = await detalle(orden.id, recepcion);

    expect(res.body.data).toMatchObject({ observations: 'Cliente pidió revisar luces', recommendations: 'Cambiar llantas' });
  });

  it('test_el_administrador_puede_editar_cualquier_orden', async () => {
    expect((await work(orden.id, { diagnosis: 'Revisión del administrador' }, admin)).status).toBe(200);
  });

  it('test_se_puede_editar_en_cualquier_estado_anterior_a_entregado', async () => {
    for (const estado of ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO']) {
      await query('UPDATE service_orders SET status = ? WHERE id = ?', [estado, orden.id]);
      expect((await work(orden.id, { observations: `En ${estado}` })).status).toBe(200);
    }
  });
});

describe.each([
  ['services', createService],
  ['labor', createLabor],
])('líneas de %s (US5, CA-4)', (kind, crearLinea) => {
  it('test_alta_correccion_y_baja_recalculan_los_totales_sin_errores_de_redondeo', async () => {
    const a = await alta(kind, orden.id, { description: 'Línea A', amount: 0.1 });
    const b = await alta(kind, orden.id, { description: 'Línea B', amount: 0.2 });
    expect(b.body.data.totals.total).toBe('0.30');

    const corregida = await request(app)
      .patch(`/api/orders/${orden.id}/${kind}/${a.body.data.item.id}`)
      .set(auth(mecanico.token))
      .send({ description: 'Línea A corregida', amount: '1234.56' });
    expect(corregida.body.data.item).toEqual({ id: a.body.data.item.id, description: 'Línea A corregida', amount: '1234.56' });
    expect(corregida.body.data.totals.total).toBe('1234.76');

    const baja = await request(app).delete(`/api/orders/${orden.id}/${kind}/${b.body.data.item.id}`).set(auth(mecanico.token));
    expect(baja.body.data.totals.total).toBe('1234.56');

    const lectura = (await detalle(orden.id)).body.data;
    expect(lectura[kind]).toHaveLength(1);
    expect(lectura.totals.total).toBe('1234.56');
  });

  it('test_acepta_importe_cero_y_el_maximo_y_rechaza_mas_de_dos_decimales', async () => {
    expect((await alta(kind, orden.id, { description: 'Cortesía', amount: 0 })).status).toBe(201);
    expect((await alta(kind, orden.id, { description: 'Máximo', amount: 9999999.99 })).status).toBe(201);
    for (const amount of [10000000, -0.01, 1.234, 'abc']) {
      const res = await alta(kind, orden.id, { description: 'X', amount });
      expect(res.status).toBe(400);
      expect(res.body.error.details.map((d) => d.field)).toContain('amount');
    }
  });

  it('test_la_descripcion_admite_hasta_255_caracteres', async () => {
    expect((await alta(kind, orden.id, { description: 'a'.repeat(255), amount: 1 })).status).toBe(201);
    const res = await alta(kind, orden.id, { description: 'a'.repeat(256), amount: 1 });
    expect(res.status).toBe(400);
    expect(res.body.error.details[0].field).toBe('description');
  });

  it('test_una_linea_inexistente_o_de_otra_orden_responde_404', async () => {
    const otraOrden = await createOrder(vehiculos[1].id, recepcion.id, { mechanicId: mecanico.id });
    const ajena = await crearLinea(otraOrden.id);

    const editar = await request(app)
      .patch(`/api/orders/${orden.id}/${kind}/${ajena.id}`)
      .set(auth(mecanico.token))
      .send({ amount: 5 });
    const borrar = await request(app).delete(`/api/orders/${orden.id}/${kind}/${ajena.id}`).set(auth(mecanico.token));
    const inexistente = await request(app).delete(`/api/orders/${orden.id}/${kind}/999999`).set(auth(mecanico.token));

    for (const res of [editar, borrar, inexistente]) {
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    }
    const [{ total }] = await query(`SELECT COUNT(*) AS total FROM ${kind === 'services' ? 'order_services' : 'order_labor'} WHERE id = ?`, [ajena.id]);
    expect(Number(total)).toBe(1);
  });

  it('test_otro_mecanico_recibe_404_sin_modificar_nada', async () => {
    const linea = await crearLinea(orden.id);

    const crear = await alta(kind, orden.id, { description: 'Intruso', amount: 1 }, otroMecanico);
    const editar = await request(app)
      .patch(`/api/orders/${orden.id}/${kind}/${linea.id}`)
      .set(auth(otroMecanico.token))
      .send({ amount: 9 });
    const borrar = await request(app).delete(`/api/orders/${orden.id}/${kind}/${linea.id}`).set(auth(otroMecanico.token));

    for (const res of [crear, editar, borrar]) expect(res.status).toBe(404);
    expect((await detalle(orden.id)).body.data[kind]).toHaveLength(1);
  });

  it('test_recepcion_recibe_403_y_el_administrador_si_puede', async () => {
    const res = await alta(kind, orden.id, { description: 'X', amount: 1 }, recepcion);
    expect(res.status).toBe(403);
    expect((await alta(kind, orden.id, { description: 'Del administrador', amount: 1 }, admin)).status).toBe(201);
  });

  it('test_una_orden_entregada_es_de_solo_lectura_para_cada_operacion', async () => {
    const linea = await crearLinea(orden.id);
    await query("UPDATE service_orders SET status = 'ENTREGADO' WHERE id = ?", [orden.id]);

    const crear = await alta(kind, orden.id, { description: 'Tarde', amount: 1 });
    const editar = await request(app)
      .patch(`/api/orders/${orden.id}/${kind}/${linea.id}`)
      .set(auth(mecanico.token))
      .send({ amount: 7 });
    const borrar = await request(app).delete(`/api/orders/${orden.id}/${kind}/${linea.id}`).set(auth(mecanico.token));

    for (const res of [crear, editar, borrar]) {
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_READ_ONLY');
    }
    expect((await detalle(orden.id)).body.data[kind]).toHaveLength(1);
  });
});

describe('orden entregada: el trabajo no se modifica', () => {
  it('test_no_se_edita_el_diagnostico_ni_las_recomendaciones_de_una_orden_entregada', async () => {
    await work(orden.id, { diagnosis: 'Original' });
    await query("UPDATE service_orders SET status = 'ENTREGADO' WHERE id = ?", [orden.id]);

    const res = await work(orden.id, { diagnosis: 'Alterado' });
    const admin403 = await work(orden.id, { diagnosis: 'Alterado' }, admin);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
    expect(admin403.status).toBe(409);
    expect((await detalle(orden.id)).body.data.diagnosis).toBe('Original');
  });

  it('test_otro_mecanico_no_puede_editar_el_trabajo_de_una_orden_ajena', async () => {
    const res = await work(orden.id, { diagnosis: 'Ajeno' }, otroMecanico);

    expect(res.status).toBe(404);
    expect((await detalle(orden.id)).body.data.diagnosis).toBeNull();
  });
});
