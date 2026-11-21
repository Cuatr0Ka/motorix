import request from 'supertest';
import { beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import {
  auth,
  createAppointment,
  createClientWithVehicle,
  createFinishedOrder,
  createMaintenance,
  createOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

// SC-007: con 1 000 órdenes, 1 000 citas y 1 000 mantenimientos el centro de notificaciones carga en menos de 2 s.
const TOTAL = 1000;
const LIMITE_MS = 2000;

const app = createApp();
let admin;
let recepcion;
let mecanico;

const haceDias = (dias) => new Date(Date.now() - dias * 24 * 3600 * 1000);
const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

/** Un vehículo con: orden entregada (origen del mantenimiento), mantenimiento pendiente, orden abierta y cita de hoy. */
async function crearCaso(i) {
  const { client, vehicle } = await createClientWithVehicle(
    { licensePlate: `PRF-${String(i).padStart(4, '0')}`, currentMileage: 1000 },
    { name: `Cliente de rendimiento ${i}` },
  );
  const origen = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  await createMaintenance(vehicle.id, origen.id, mecanico.id, {
    description: `Servicio ${i}`,
    dueDate: hoyMas(i % 2 === 0 ? -5 : 10),
  });
  await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION', entryMileage: 0 });
  const hoy = new Date();
  await createAppointment(client.id, vehicle.id, recepcion.id, {
    scheduledAt: new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 15, 0, 0),
  });
}

const medir = async (peticion) => {
  const inicio = Date.now();
  const res = await peticion;
  return { res, ms: Date.now() - inicio };
};

beforeAll(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');

  for (let desde = 1; desde <= TOTAL; desde += 25) {
    const lote = [];
    for (let i = desde; i < desde + 25 && i <= TOTAL; i += 1) lote.push(crearCaso(i));
    await Promise.all(lote);
  }
  // Todas las órdenes abiertas llevan más de 3 días sin cambio de estado.
  await query('UPDATE order_status_history SET changed_at = ? WHERE order_id IN (SELECT id FROM service_orders WHERE status = ?)', [
    haceDias(5),
    'EN_REPARACION',
  ]);
}, 300000);

describe('rendimiento del centro de notificaciones (SC-007, FR-023)', () => {
  it('test_los_datos_de_prueba_son_mil_de_cada_tipo', async () => {
    const [ordenes] = await query("SELECT COUNT(*) AS n FROM service_orders WHERE status = 'EN_REPARACION'");
    const [citas] = await query('SELECT COUNT(*) AS n FROM appointments');
    const [mantenimientos] = await query("SELECT COUNT(*) AS n FROM maintenance WHERE status = 'PENDIENTE'");

    expect(Number(ordenes.n)).toBe(TOTAL);
    expect(Number(citas.n)).toBe(TOTAL);
    expect(Number(mantenimientos.n)).toBe(TOTAL);
  });

  it('test_el_administrador_recibe_los_avisos_en_menos_de_dos_segundos_con_el_total_real', async () => {
    const { res, ms } = await medir(request(app).get('/api/notifications').set(auth(admin.token)));

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
    const grupos = Object.fromEntries(res.body.data.groups.map((g) => [g.type, g]));
    expect(grupos.STALLED.total).toBe(TOTAL);
    expect(grupos.APPT_TODAY.total).toBe(TOTAL);
    expect(grupos.MAINT_OVERDUE.total).toBe(TOTAL / 2);
    expect(grupos.MAINT_UPCOMING.total).toBe(TOTAL / 2);
    for (const grupo of Object.values(grupos)) expect(grupo.items.length).toBeLessThanOrEqual(50);
    expect(res.body.data.total).toBe(TOTAL * 3);
    expect(res.body.data.unread).toBe(TOTAL * 3);
  });

  it('test_la_recepcion_recibe_los_avisos_en_menos_de_dos_segundos', async () => {
    const { res, ms } = await medir(request(app).get('/api/notifications').set(auth(recepcion.token)));

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
    expect(res.body.data.total).toBe(TOTAL * 3);
  });

  it('test_el_mecanico_recibe_sus_ordenes_detenidas_en_menos_de_dos_segundos', async () => {
    const { res, ms } = await medir(request(app).get('/api/notifications').set(auth(mecanico.token)));

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
    expect(res.body.data.total).toBe(TOTAL);
  });

  it('test_la_lista_de_clientes_por_avisar_responde_en_menos_de_dos_segundos_y_limita_a_doscientas', async () => {
    const { res, ms } = await medir(request(app).get('/api/client-notices').set(auth(recepcion.token)));

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
    expect(res.body.data).toHaveLength(200);
    expect(res.body.meta.total).toBeGreaterThanOrEqual(TOTAL);
  });

  it('test_marcar_como_leido_con_mil_avisos_responde_en_menos_de_dos_segundos', async () => {
    const lista = await request(app).get('/api/notifications').set(auth(admin.token));
    const claves = lista.body.data.groups[0].items.slice(0, 50).map((i) => i.key);

    const { res, ms } = await medir(request(app).post('/api/notifications/read').set(auth(admin.token)).send({ keys: claves }));

    expect(res.status).toBe(200);
    expect(ms).toBeLessThan(LIMITE_MS);
    expect(res.body.data.marked).toBe(50);
  });
});
