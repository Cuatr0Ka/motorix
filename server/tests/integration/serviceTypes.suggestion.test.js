import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createClientWithVehicle,
  createOrder,
  createServiceType,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let orden;

const sugerencia = (token = mecanico.token, id = orden.id) => request(app).get(`/api/orders/${id}/maintenance/suggestion`).set(auth(token));

async function agregarServicio(tipo) {
  await query('INSERT INTO order_services (order_id, description, amount, service_type_id) VALUES (?, ?, ?, ?)', [
    orden.id,
    'Servicio',
    100,
    tipo?.id ?? null,
  ]);
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ currentMileage: 40000 });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO', entryMileage: 39000 });
});

describe('próximo mantenimiento propuesto (US3, FR-007)', () => {
  it('test_propone_fecha_y_kilometraje_con_el_intervalo_mas_corto_de_las_lineas', async () => {
    await agregarServicio(await createServiceType({ name: 'Aceite', intervalDays: 180, intervalKm: 5000 }));
    await agregarServicio(await createServiceType({ name: 'Frenos', intervalDays: 90, intervalKm: 20000 }));

    const res = await sugerencia();

    expect(res.status).toBe(200);
    expect(res.body.data.dueMileage).toBe(45000); // 40 000 actual + 5 000
    expect(res.body.data.dueDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(res.body.data.basedOn.map((t) => t.name).sort()).toEqual(['Aceite', 'Frenos']);
  });

  it('test_responde_204_si_ninguna_linea_tiene_un_tipo_con_intervalo', async () => {
    await agregarServicio(null);
    expect((await sugerencia()).status).toBe(204);
  });

  it('test_un_mecanico_ajeno_recibe_404_y_recepcion_403', async () => {
    await agregarServicio(await createServiceType());
    const otro = await createUserWithToken('MECHANIC');

    expect((await sugerencia(otro.token)).status).toBe(404);
    expect((await sugerencia(recepcion.token)).status).toBe(403);
    expect((await sugerencia(admin.token)).status).toBe(200);
    expect((await sugerencia(mecanico.token, 99999)).status).toBe(404);
  });

  it('test_programar_con_la_propuesta_corregida_conserva_las_validaciones', async () => {
    await agregarServicio(await createServiceType({ intervalDays: null, intervalKm: 5000 }));
    const propuesta = (await sugerencia()).body.data;

    const invalido = await request(app)
      .post(`/api/orders/${orden.id}/maintenance`)
      .set(auth(mecanico.token))
      .send({ description: 'Cambio de aceite', dueMileage: 30000 }); // menor al kilometraje actual
    expect(invalido.status).toBe(422);

    const valido = await request(app)
      .post(`/api/orders/${orden.id}/maintenance`)
      .set(auth(mecanico.token))
      .send({ description: 'Cambio de aceite', dueMileage: propuesta.dueMileage });
    expect(valido.status).toBe(201);
  });
});
