import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
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
let recepcion;
let mecanico;
let seq = 0;

const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

/** Mantenimiento pendiente de un vehículo nuevo, con fecha objetivo relativa a hoy. */
async function crearMantenimiento({ dias, descripcion, cliente }) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle(
    { licensePlate: `NTF-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 },
    cliente ? { name: cliente } : {},
  );
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  const mantenimiento = await createMaintenance(vehicle.id, orden.id, mecanico.id, {
    description: descripcion ?? `Servicio ${seq}`,
    dueDate: hoyMas(dias),
  });
  return { ...mantenimiento, vehicle };
}

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('centro de notificaciones: consulta (US1, FR-001, FR-003)', () => {
  it('test_sin_avisos_devuelve_cero_y_ningun_grupo', async () => {
    const res = await consultar(admin);

    expect(res.status).toBe(200);
    expect(res.body.data.unread).toBe(0);
    expect(res.body.data.total).toBe(0);
    expect(res.body.data.groups).toEqual([]);
    expect(typeof res.body.data.generatedAt).toBe('string');
  });

  it('test_con_un_mantenimiento_vencido_devuelve_un_grupo_con_su_aviso', async () => {
    const caso = await crearMantenimiento({ dias: -5, descripcion: 'Cambio de aceite', cliente: 'Juan Pérez' });

    const res = await consultar(admin);

    expect(res.status).toBe(200);
    expect(res.body.data.unread).toBe(1);
    expect(res.body.data.total).toBe(1);
    expect(res.body.data.groups).toHaveLength(1);
    const grupo = res.body.data.groups[0];
    expect(grupo.type).toBe('MAINT_OVERDUE');
    expect(grupo.total).toBe(1);
    expect(grupo.unread).toBe(1);
    const aviso = grupo.items[0];
    expect(aviso.key).toBe(`MAINT_OVERDUE:${caso.id}`);
    expect(aviso.read).toBe(false);
    expect(aviso.detail).toContain('Cambio de aceite');
    expect(aviso.detail).toContain('Juan Pérez');
    expect(aviso.target).toEqual({ kind: 'vehicle', id: caso.vehicle.id });
  });

  it('test_un_mantenimiento_que_no_esta_vencido_no_genera_aviso_de_vencido', async () => {
    await crearMantenimiento({ dias: 120 });

    const res = await consultar(admin);

    expect(res.body.data.groups.find((g) => g.type === 'MAINT_OVERDUE')).toBeUndefined();
  });

  it('test_un_mantenimiento_atendido_no_genera_aviso', async () => {
    const caso = await crearMantenimiento({ dias: -5 });
    const { query } = await import('../../config/db.js');
    await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [caso.id]);

    const res = await consultar(admin);

    expect(res.body.data.total).toBe(0);
  });

  it('test_sin_token_responde_401', async () => {
    const res = await request(app).get('/api/notifications');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('test_con_mas_de_cincuenta_avisos_lista_cincuenta_y_cuenta_todos', async () => {
    for (let i = 0; i < 60; i += 1) await crearMantenimiento({ dias: -3 });

    const res = await consultar(admin);

    const grupo = res.body.data.groups.find((g) => g.type === 'MAINT_OVERDUE');
    expect(grupo.items).toHaveLength(50);
    expect(grupo.total).toBe(60);
    expect(grupo.unread).toBe(60);
    expect(res.body.data.unread).toBe(60);
    expect(res.body.data.total).toBe(60);
  });

  it('test_el_rol_vigente_en_la_base_decide_los_avisos', async () => {
    await crearMantenimiento({ dias: -5 });
    const { query } = await import('../../config/db.js');
    // El token sigue siendo el de recepción, pero la persona pasa a ser mecánico: ya no ve mantenimientos.
    await query("UPDATE users SET role = 'MECHANIC' WHERE id = ?", [recepcion.id]);

    const res = await consultar(recepcion);

    expect(res.status).toBe(200);
    expect(res.body.data.groups).toEqual([]);
  });
});
