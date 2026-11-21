import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createServiceType, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
});

describe('contrato de /api/service-types', () => {
  it('test_get_lista_devuelve_la_forma_del_contrato_con_in_use', async () => {
    await createServiceType({ name: 'Cambio de aceite', intervalDays: 180, intervalKm: 5000 });
    const res = await request(app).get('/api/service-types').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.meta).toEqual({ total: 1 });
    expect(Object.keys(res.body.data[0]).sort()).toEqual(['active', 'id', 'inUse', 'intervalDays', 'intervalKm', 'name']);
    expect(res.body.data[0]).toMatchObject({ name: 'Cambio de aceite', intervalDays: 180, intervalKm: 5000, active: true, inUse: 0 });
  });

  it('test_get_lista_filtra_por_activo', async () => {
    await createServiceType({ name: 'A' });
    await createServiceType({ name: 'B', active: 0 });

    expect((await request(app).get('/api/service-types?active=true').set(auth(admin.token))).body.data.map((t) => t.name)).toEqual(['A']);
    expect((await request(app).get('/api/service-types?active=false').set(auth(admin.token))).body.data.map((t) => t.name)).toEqual(['B']);
  });

  it('test_options_devuelve_solo_id_nombre_y_los_dos_intervalos', async () => {
    await createServiceType();
    const res = await request(app).get('/api/service-types/options').set(auth(admin.token));

    expect(Object.keys(res.body.data[0]).sort()).toEqual(['id', 'intervalDays', 'intervalKm', 'name']);
  });

  it('test_post_y_patch_devuelven_el_tipo_con_la_misma_forma', async () => {
    const alta = await request(app).post('/api/service-types').set(auth(admin.token)).send({ name: 'Afinación mayor', intervalDays: 365, intervalKm: 10000 });
    expect(alta.status).toBe(201);
    expect(Object.keys(alta.body.data).sort()).toEqual(['active', 'id', 'inUse', 'intervalDays', 'intervalKm', 'name']);

    const edicion = await request(app).patch(`/api/service-types/${alta.body.data.id}`).set(auth(admin.token)).send({ name: 'Afinación completa' });
    expect(edicion.status).toBe(200);
    expect(edicion.body.data.name).toBe('Afinación completa');
  });

  it('test_recepcion_y_mecanico_reciben_403_en_la_gestion_y_sin_token_401', async () => {
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const mecanico = await createUserWithToken('MECHANIC');

    for (const token of [recepcion.token, mecanico.token]) {
      expect((await request(app).get('/api/service-types').set(auth(token))).status).toBe(403);
      expect((await request(app).post('/api/service-types').set(auth(token)).send({ name: 'X', intervalDays: 1 })).status).toBe(403);
      expect((await request(app).patch('/api/service-types/1').set(auth(token)).send({ active: false })).status).toBe(403);
    }
    expect((await request(app).get('/api/service-types')).status).toBe(401);
  });

  it('test_patch_de_un_tipo_inexistente_da_404', async () => {
    const res = await request(app).patch('/api/service-types/99999').set(auth(admin.token)).send({ active: false });

    expect(res.status).toBe(404);
  });
});
