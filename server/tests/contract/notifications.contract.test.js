import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;

beforeAll(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  const mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ currentMileage: 1000 });
  const orden = await createFinishedOrder(vehicle.id, admin.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  await createMaintenance(vehicle.id, orden.id, mecanico.id, {
    description: 'Cambio de aceite',
    dueDate: new Date(Date.now() - 5 * 24 * 3600 * 1000),
  });
});

describe('contrato de GET /api/notifications', () => {
  it('test_la_respuesta_cumple_la_forma_del_contrato', async () => {
    const res = await request(app).get('/api/notifications').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(Object.keys(res.body)).toEqual(['data']);
    const { data } = res.body;
    expect(Number.isInteger(data.unread)).toBe(true);
    expect(Number.isInteger(data.total)).toBe(true);
    expect(Number.isNaN(Date.parse(data.generatedAt))).toBe(false);
    expect(Array.isArray(data.groups)).toBe(true);

    const grupo = data.groups[0];
    expect(Object.keys(grupo).sort()).toEqual(['items', 'total', 'type', 'unread']);
    expect(Array.isArray(grupo.items)).toBe(true);

    const aviso = grupo.items[0];
    expect(typeof aviso.key).toBe('string');
    expect(aviso.type).toBe(grupo.type);
    expect(typeof aviso.read).toBe('boolean');
    expect(typeof aviso.title).toBe('string');
    expect(typeof aviso.detail).toBe('string');
    expect(['order', 'appointment', 'vehicle', 'part']).toContain(aviso.target.kind);
    expect(Number.isInteger(aviso.target.id)).toBe(true);
  });

  it('test_el_aviso_de_mantenimiento_trae_la_fecha_objetivo', async () => {
    const res = await request(app).get('/api/notifications').set(auth(admin.token));

    const aviso = res.body.data.groups.find((g) => g.type === 'MAINT_OVERDUE').items[0];
    expect(aviso.dueDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('test_no_acepta_parametros_y_los_ignora', async () => {
    const res = await request(app).get('/api/notifications?page=9&pageSize=1').set(auth(admin.token));

    expect(res.status).toBe(200);
  });

  it('test_las_rutas_inexistentes_de_notificaciones_responden_404', async () => {
    const res = await request(app).delete('/api/notifications').set(auth(admin.token));

    expect(res.status).toBe(404);
  });
});
