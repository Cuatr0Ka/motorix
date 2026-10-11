import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
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
let mecanico;
let vehiculo;

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC', { name: 'Mario Mecánico' });
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'MEC-001-A' }));
});

describe('GET /api/mechanics (contrato)', () => {
  it('test_devuelve_solo_id_nombre_y_usuario_de_los_mecanicos_activos', async () => {
    await createUserWithToken('MECHANIC', { name: 'Inactivo', active: 0 });

    const res = await request(app).get('/api/mechanics').set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([{ id: mecanico.id, name: 'Mario Mecánico', username: mecanico.username }]);
  });

  it('test_no_expone_correo_ni_hash_ni_usuarios_de_otros_roles', async () => {
    const res = await request(app).get('/api/mechanics').set(auth(admin.token));

    const texto = JSON.stringify(res.body);
    expect(texto).not.toMatch(/email|password|hash|\$2[aby]\$/i);
    expect(res.body.data.map((m) => m.id)).not.toContain(recepcion.id);
    expect(res.body.data.map((m) => m.id)).not.toContain(admin.id);
  });

  it('test_ordena_por_nombre', async () => {
    await createUserWithToken('MECHANIC', { name: 'Ana Mecánica' });

    const res = await request(app).get('/api/mechanics').set(auth(recepcion.token));

    expect(res.body.data.map((m) => m.name)).toEqual(['Ana Mecánica', 'Mario Mecánico']);
  });

  it('test_sin_token_401_y_el_mecanico_recibe_403', async () => {
    expect((await request(app).get('/api/mechanics')).status).toBe(401);
    const res = await request(app).get('/api/mechanics').set(auth(mecanico.token));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});

describe('PUT /api/orders/:id/mechanic (contrato)', () => {
  it('test_asigna_el_mecanico_y_devuelve_el_detalle', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await request(app)
      .put(`/api/orders/${orden.id}/mechanic`)
      .set(auth(recepcion.token))
      .send({ mechanicId: mecanico.id });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: orden.id,
      mechanic: { id: mecanico.id, name: 'Mario Mecánico' },
      services: [],
      labor: [],
      totals: { total: '0.00' },
    });
  });

  it('test_rechaza_un_mecanico_invalido_con_422', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await request(app)
      .put(`/api/orders/${orden.id}/mechanic`)
      .set(auth(recepcion.token))
      .send({ mechanicId: recepcion.id });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('MECHANIC_INVALID');
  });

  it('test_rechaza_un_cuerpo_invalido_con_400', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const res = await request(app).put(`/api/orders/${orden.id}/mechanic`).set(auth(recepcion.token)).send({ mechanicId: 'x' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('test_orden_inexistente_404_sin_token_401_y_mecanico_403', async () => {
    const orden = await createOrder(vehiculo.id, recepcion.id);

    const noExiste = await request(app).put('/api/orders/999999/mechanic').set(auth(recepcion.token)).send({ mechanicId: mecanico.id });
    expect(noExiste.status).toBe(404);
    expect((await request(app).put(`/api/orders/${orden.id}/mechanic`).send({ mechanicId: mecanico.id })).status).toBe(401);
    const prohibido = await request(app)
      .put(`/api/orders/${orden.id}/mechanic`)
      .set(auth(mecanico.token))
      .send({ mechanicId: mecanico.id });
    expect(prohibido.status).toBe(403);
  });
});
