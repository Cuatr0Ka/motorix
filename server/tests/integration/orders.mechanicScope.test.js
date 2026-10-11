import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let admin;
let mecanico1;
let mecanico2;
let o1; // asignada a mecánico 1, en diagnóstico
let o2; // asignada a mecánico 2
let o3; // asignada a mecánico 1, entregada
let o4; // sin asignar

const listar = (user, q = '') => request(app).get(`/api/orders${q}`).set(auth(user.token));
const ids = (res) => res.body.data.map((o) => o.id).sort((a, b) => a - b);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico1 = await createUserWithToken('MECHANIC', { name: 'Mario Mecánico' });
  mecanico2 = await createUserWithToken('MECHANIC', { name: 'Marta Mecánica' });

  const v1 = await createClientWithVehicle({ licensePlate: 'SCP-001-A' }, { name: 'Ana Morales' });
  const v2 = await createClientWithVehicle({ licensePlate: 'SCP-002-B' }, { name: 'Luis Pérez' });
  const v3 = await createClientWithVehicle({ licensePlate: 'SCP-003-C' }, { name: 'Rosa Gómez' });
  const v4 = await createClientWithVehicle({ licensePlate: 'SCP-004-D' }, { name: 'Omar Díaz' });
  o1 = await createOrder(v1.vehicle.id, recepcion.id, { mechanicId: mecanico1.id, status: 'DIAGNOSTICO' });
  o2 = await createOrder(v2.vehicle.id, recepcion.id, { mechanicId: mecanico2.id, status: 'EN_REPARACION' });
  o3 = await createOrder(v3.vehicle.id, recepcion.id, { mechanicId: mecanico1.id, status: 'ENTREGADO' });
  o4 = await createOrder(v4.vehicle.id, recepcion.id);
});

describe('el mecánico ve únicamente sus órdenes (US4, CA-3)', () => {
  it('test_lista_solo_las_asignadas_a_el_y_sin_las_entregadas_por_defecto', async () => {
    const res = await listar(mecanico1);

    expect(res.status).toBe(200);
    expect(ids(res)).toEqual([o1.id]);
    expect(res.body.meta.total).toBe(1);
    expect(res.body.data[0]).toMatchObject({ id: o1.id, mechanic: { id: mecanico1.id }, status: 'DIAGNOSTICO' });
  });

  it('test_con_el_filtro_entregado_muestra_las_entregadas_que_tuvo_asignadas', async () => {
    const res = await listar(mecanico1, '?status=ENTREGADO');

    expect(ids(res)).toEqual([o3.id]);
  });

  it('test_ignora_el_filtro_de_mecanico_que_envie', async () => {
    const res = await listar(mecanico1, `?mechanicId=${mecanico2.id}`);

    expect(ids(res)).toEqual([o1.id]);
  });

  it('test_cada_mecanico_ve_las_suyas_y_no_las_del_otro', async () => {
    expect(ids(await listar(mecanico1))).toEqual([o1.id]);
    expect(ids(await listar(mecanico2))).toEqual([o2.id]);
  });

  it('test_un_mecanico_sin_ordenes_recibe_una_lista_vacia', async () => {
    const otro = await createUserWithToken('MECHANIC');

    const res = await listar(otro);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
    expect(res.body.meta.total).toBe(0);
  });

  it('test_los_filtros_de_estado_y_la_busqueda_respetan_su_alcance', async () => {
    expect(ids(await listar(mecanico1, '?status=DIAGNOSTICO'))).toEqual([o1.id]);
    expect(ids(await listar(mecanico1, '?status=EN_REPARACION'))).toEqual([]);
    expect(ids(await listar(mecanico1, '?search=Ana'))).toEqual([o1.id]);
    expect(ids(await listar(mecanico1, '?search=Luis'))).toEqual([]);
    expect(ids(await listar(mecanico1, '?search=SCP-001'))).toEqual([o1.id]);
  });
});

describe('abrir una orden ajena (404 sin revelar datos)', () => {
  it('test_una_orden_ajena_responde_igual_que_una_inexistente', async () => {
    const ajena = await request(app).get(`/api/orders/${o2.id}`).set(auth(mecanico1.token));
    const inexistente = await request(app).get('/api/orders/999999').set(auth(mecanico1.token));

    expect(ajena.status).toBe(404);
    expect(ajena.body).toEqual(inexistente.body);
    expect(JSON.stringify(ajena.body)).not.toContain('Luis');
  });

  it('test_una_orden_sin_asignar_tampoco_es_visible_para_un_mecanico', async () => {
    const res = await request(app).get(`/api/orders/${o4.id}`).set(auth(mecanico1.token));

    expect(res.status).toBe(404);
  });

  it('test_el_mecanico_si_abre_la_suya_con_sus_transiciones_permitidas', async () => {
    const res = await request(app).get(`/api/orders/${o1.id}`).set(auth(mecanico1.token));

    expect(res.status).toBe(200);
    expect(res.body.data.allowedTransitions).toEqual(['EN_REPARACION', 'ESPERANDO_REFACCION']);
  });

  it('test_el_mecanico_puede_abrir_una_suya_ya_entregada_aunque_no_aparezca_por_defecto', async () => {
    const res = await request(app).get(`/api/orders/${o3.id}`).set(auth(mecanico1.token));

    expect(res.status).toBe(200);
    expect(res.body.data.allowedTransitions).toEqual([]);
  });
});

describe('recepción y administración ven todas', () => {
  it.each(['recepcion', 'admin'])('test_%s_lista_todas_las_ordenes', async (quien) => {
    const user = quien === 'admin' ? admin : recepcion;

    const res = await listar(user);

    expect(ids(res)).toEqual([o1.id, o2.id, o3.id, o4.id]);
    expect(res.body.meta.total).toBe(4);
  });

  it('test_filtra_por_estado_y_por_mecanico', async () => {
    expect(ids(await listar(recepcion, '?status=ENTREGADO'))).toEqual([o3.id]);
    expect(ids(await listar(recepcion, `?mechanicId=${mecanico1.id}`))).toEqual([o1.id, o3.id]);
    expect(ids(await listar(recepcion, `?mechanicId=${mecanico1.id}&status=DIAGNOSTICO`))).toEqual([o1.id]);
  });

  it('test_busca_por_folio_cliente_y_placa', async () => {
    expect(ids(await listar(recepcion, `?search=OS-${o2.id}`))).toEqual([o2.id]);
    expect(ids(await listar(recepcion, `?search=${String(o2.id).padStart(6, '0')}`))).toEqual([o2.id]);
    expect(ids(await listar(recepcion, `?search=${encodeURIComponent('Rosa')}`))).toEqual([o3.id]);
    expect(ids(await listar(recepcion, '?search=SCP-004'))).toEqual([o4.id]);
  });

  it('test_pagina_y_ordena_las_mas_recientes_primero', async () => {
    const res = await listar(recepcion, '?page=1&pageSize=2');

    expect(res.body.data.map((o) => o.id)).toEqual([o4.id, o3.id]);
    expect(res.body.meta).toEqual({ page: 1, pageSize: 2, total: 4 });
  });

  it('test_recepcion_ve_cualquier_orden_por_id', async () => {
    expect((await request(app).get(`/api/orders/${o2.id}`).set(auth(recepcion.token))).status).toBe(200);
  });
});

describe('sesión del mecánico', () => {
  it('test_un_mecanico_desactivado_despues_de_iniciar_sesion_es_rechazado_en_la_siguiente_peticion', async () => {
    expect((await listar(mecanico1)).status).toBe(200);
    await query('UPDATE users SET active = 0 WHERE id = ?', [mecanico1.id]);

    const res = await listar(mecanico1);

    expect(res.status).toBe(401);
  });

  it('test_un_cambio_de_rol_rige_de_inmediato', async () => {
    await query("UPDATE users SET role = 'RECEPTIONIST' WHERE id = ?", [mecanico1.id]);

    const res = await listar(mecanico1);

    expect(ids(res)).toEqual([o1.id, o2.id, o3.id, o4.id]);
  });
});

describe('escrituras sobre órdenes ajenas (US5 y US6)', () => {
  it('test_un_mecanico_recibe_404_en_cada_operacion_de_escritura_sobre_una_orden_ajena', async () => {
    const linea = await request(app)
      .post(`/api/orders/${o2.id}/services`)
      .set(auth(mecanico2.token))
      .send({ description: 'Propia', amount: 10 });
    const lineaId = linea.body.data.item.id;

    const intentos = [
      request(app).patch(`/api/orders/${o2.id}/work`).set(auth(mecanico1.token)).send({ diagnosis: 'Intruso' }),
      request(app).post(`/api/orders/${o2.id}/services`).set(auth(mecanico1.token)).send({ description: 'Intruso', amount: 1 }),
      request(app).patch(`/api/orders/${o2.id}/services/${lineaId}`).set(auth(mecanico1.token)).send({ amount: 99 }),
      request(app).delete(`/api/orders/${o2.id}/services/${lineaId}`).set(auth(mecanico1.token)),
      request(app).post(`/api/orders/${o2.id}/labor`).set(auth(mecanico1.token)).send({ description: 'Intruso', amount: 1 }),
      request(app).post(`/api/orders/${o2.id}/status`).set(auth(mecanico1.token)).send({ status: 'TERMINADO' }),
    ];

    for (const res of await Promise.all(intentos)) {
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    }
    const [orden] = await query('SELECT status, diagnosis FROM service_orders WHERE id = ?', [o2.id]);
    expect(orden).toEqual({ status: 'EN_REPARACION', diagnosis: null });
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM order_services WHERE order_id = ?', [o2.id]);
    expect(Number(total)).toBe(1);
  });
});
