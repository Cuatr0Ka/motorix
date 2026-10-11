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
let vehiculo;

const asignar = (id, mechanicId, user = recepcion) =>
  request(app).put(`/api/orders/${id}/mechanic`).set(auth(user.token)).send({ mechanicId });
const idsDe = async (user) =>
  (await request(app).get('/api/orders').set(auth(user.token))).body.data.map((o) => o.id);

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico1 = await createUserWithToken('MECHANIC');
  mecanico2 = await createUserWithToken('MECHANIC');
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'ASG-001-A' }));
});

describe('asignar y reasignar una orden (US3)', () => {
  it('test_asigna_una_orden_sin_mecanico_y_solo_ese_mecanico_la_ve', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await asignar(orden.id, mecanico1.id);

    expect(res.status).toBe(200);
    expect(res.body.data.mechanic.id).toBe(mecanico1.id);
    expect(await idsDe(mecanico1)).toEqual([orden.id]);
    expect(await idsDe(mecanico2)).toEqual([]);
  });

  it('test_reasigna_y_la_orden_cambia_de_lista', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id, status: 'EN_REPARACION' });

    const res = await asignar(orden.id, mecanico2.id);

    expect(res.status).toBe(200);
    expect(await idsDe(mecanico1)).toEqual([]);
    expect(await idsDe(mecanico2)).toEqual([orden.id]);
  });

  it('test_el_administrador_tambien_puede_asignar', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    expect((await asignar(orden.id, mecanico1.id, admin)).status).toBe(200);
  });

  it('test_quita_la_asignacion_con_null_solo_mientras_esta_recibida', async () => {
    const recibida = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id });
    const quitada = await asignar(recibida.id, null);
    expect(quitada.status).toBe(200);
    expect(quitada.body.data.mechanic).toBeNull();

    await query("UPDATE service_orders SET mechanic_id = ?, status = 'DIAGNOSTICO' WHERE id = ?", [mecanico1.id, recibida.id]);
    const rechazada = await asignar(recibida.id, null);
    expect(rechazada.status).toBe(409);
    expect(rechazada.body.error.code).toBe('ORDER_NOT_ASSIGNABLE');
  });

  it('test_asignar_al_mismo_mecanico_otra_vez_no_falla', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id });

    expect((await asignar(orden.id, mecanico1.id)).status).toBe(200);
  });
});

describe('mecánicos no válidos (MECHANIC_INVALID)', () => {
  it('test_rechaza_un_usuario_inactivo_uno_de_otro_rol_y_uno_inexistente', async () => {
    const inactivo = await createUserWithToken('MECHANIC', { active: 0 });
    const orden = await createOrder(vehiculo.id, recepcion.id);

    for (const id of [inactivo.id, recepcion.id, admin.id, 999999]) {
      const res = await asignar(orden.id, id);
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('MECHANIC_INVALID');
    }
    const [fila] = await query('SELECT mechanic_id FROM service_orders WHERE id = ?', [orden.id]);
    expect(fila.mechanic_id).toBeNull();
  });
});

describe('órdenes cerradas', () => {
  it('test_no_se_reasigna_una_orden_terminada', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id, status: 'TERMINADO' });

    const res = await asignar(orden.id, mecanico2.id);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_NOT_ASSIGNABLE');
    expect(await idsDe(mecanico1)).toEqual([orden.id]);
  });

  it('test_no_se_reasigna_una_orden_entregada', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id, status: 'ENTREGADO' });

    const res = await asignar(orden.id, mecanico2.id);

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_READ_ONLY');
  });

  it('test_un_mecanico_desactivado_despues_conserva_la_asignacion_y_se_puede_reasignar', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id, status: 'DIAGNOSTICO' });
    await query('UPDATE users SET active = 0 WHERE id = ?', [mecanico1.id]);

    const detalle = await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token));
    expect(detalle.body.data.mechanic.id).toBe(mecanico1.id);

    expect((await asignar(orden.id, mecanico2.id)).status).toBe(200);
  });
});

describe('permisos', () => {
  it('test_un_mecanico_no_puede_asignar_ni_reasignarse_ordenes', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id, { mechanicId: mecanico1.id });

    const res = await asignar(orden.id, mecanico2.id, mecanico1);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});
