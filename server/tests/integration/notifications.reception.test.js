import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createAppointment,
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

/** Fecha de hoy (o de otro día) a una hora fija, para que la prueba no dependa de la hora en que corre. */
const diaALas = (diasDesdeHoy, hora = 15) => {
  const ahora = new Date();
  return new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + diasDesdeHoy, hora, 0, 0);
};

async function crearMantenimiento({ dias, descripcion = 'Cambio de aceite', cliente = 'Juan Pérez' }) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle(
    { licensePlate: `REC-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 },
    { name: cliente },
  );
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  const mantenimiento = await createMaintenance(vehicle.id, orden.id, mecanico.id, { description: descripcion, dueDate: hoyMas(dias) });
  return { ...mantenimiento, vehicle };
}

async function crearCita({ dia, hora = 15, status = 'PENDIENTE', cliente = 'Ana Torres' }) {
  seq += 1;
  const { client, vehicle } = await createClientWithVehicle(
    { licensePlate: `CIT-${String(seq).padStart(3, '0')}-Z` },
    { name: cliente },
  );
  const cita = await createAppointment(client.id, vehicle.id, recepcion.id, {
    scheduledAt: diaALas(dia, hora),
    status,
    reason: 'Revisión general',
  });
  return { ...cita, vehicle };
}

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));
const grupo = (res, tipo) => res.body.data.groups.find((g) => g.type === tipo);

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('avisos de mantenimientos y citas para la recepción (US2)', () => {
  it('test_la_recepcion_recibe_proximos_vencidos_y_citas_del_dia_en_grupos_separados', async () => {
    await crearMantenimiento({ dias: -5, descripcion: 'Vencido por fecha' });
    await crearMantenimiento({ dias: 10, descripcion: 'Próximo por fecha' });
    await crearCita({ dia: 0 });

    const res = await consultar(recepcion);

    expect(res.status).toBe(200);
    expect(res.body.data.groups.map((g) => g.type)).toEqual(['MAINT_OVERDUE', 'APPT_TODAY', 'MAINT_UPCOMING']);
    expect(res.body.data.total).toBe(3);
    expect(res.body.data.unread).toBe(3);
    expect(grupo(res, 'MAINT_OVERDUE').items[0].detail).toContain('Vencido por fecha');
    expect(grupo(res, 'MAINT_UPCOMING').items[0].detail).toContain('Próximo por fecha');
  });

  it('test_el_aviso_de_mantenimiento_incluye_vehiculo_y_cliente_pero_nunca_el_telefono', async () => {
    await crearMantenimiento({ dias: -5, cliente: 'Juan Pérez' });

    const res = await consultar(recepcion);

    const aviso = grupo(res, 'MAINT_OVERDUE').items[0];
    expect(aviso.detail).toContain('Juan Pérez');
    expect(aviso.detail).toMatch(/REC-001-Z/);
    expect(JSON.stringify(res.body)).not.toMatch(/phone/i);
  });

  it('test_la_cita_de_hoy_pendiente_o_confirmada_genera_aviso_con_hora_cliente_y_vehiculo', async () => {
    const pendiente = await crearCita({ dia: 0, hora: 9, cliente: 'Ana Torres' });
    const confirmada = await crearCita({ dia: 0, hora: 17, status: 'CONFIRMADA', cliente: 'Luis Gómez' });

    const res = await consultar(recepcion);

    const items = grupo(res, 'APPT_TODAY').items;
    expect(items.map((i) => i.key)).toEqual([`APPT_TODAY:${pendiente.id}`, `APPT_TODAY:${confirmada.id}`]);
    expect(items[0].title).toBe('Cita de hoy');
    expect(items[0].detail).toContain('Ana Torres');
    expect(items[0].detail).toContain('Revisión general');
    expect(items[0].detail).toContain('09:00');
    expect(items[0].target).toEqual({ kind: 'appointment', id: pendiente.id });
    expect(new Date(items[0].scheduledAt).getHours()).toBe(9);
  });

  it('test_las_citas_canceladas_completadas_o_en_proceso_no_generan_aviso', async () => {
    await crearCita({ dia: 0, status: 'CANCELADA' });
    await crearCita({ dia: 0, status: 'COMPLETADA' });
    await crearCita({ dia: 0, status: 'EN_PROCESO' });

    const res = await consultar(recepcion);

    expect(grupo(res, 'APPT_TODAY')).toBeUndefined();
    expect(res.body.data.total).toBe(0);
  });

  it('test_una_cita_de_manana_o_de_ayer_no_es_aviso_del_dia', async () => {
    await crearCita({ dia: 1 });
    await crearCita({ dia: -1 });

    const res = await consultar(recepcion);

    expect(grupo(res, 'APPT_TODAY')).toBeUndefined();
  });

  it('test_un_mantenimiento_normal_no_genera_aviso', async () => {
    await crearMantenimiento({ dias: 120 });

    const res = await consultar(recepcion);

    expect(res.body.data.groups).toEqual([]);
  });

  it('test_los_totales_de_mantenimientos_coinciden_con_el_panel_y_con_la_lista', async () => {
    await crearMantenimiento({ dias: -5 });
    await crearMantenimiento({ dias: -9 });
    await crearMantenimiento({ dias: 10 });
    await crearMantenimiento({ dias: 20 });
    await crearMantenimiento({ dias: 25 });
    await crearMantenimiento({ dias: 120 });

    const avisos = await consultar(admin);
    const panel = await request(app).get('/api/dashboard').set(auth(admin.token));
    const vencidos = await request(app).get('/api/maintenance?indicator=VENCIDO').set(auth(recepcion.token));
    const proximos = await request(app).get('/api/maintenance?indicator=PROXIMO').set(auth(recepcion.token));

    expect(grupo(avisos, 'MAINT_OVERDUE').total).toBe(panel.body.data.maintenance.overdue);
    expect(grupo(avisos, 'MAINT_UPCOMING').total).toBe(panel.body.data.maintenance.upcoming);
    expect(grupo(avisos, 'MAINT_OVERDUE').total).toBe(vencidos.body.meta.total);
    expect(grupo(avisos, 'MAINT_UPCOMING').total).toBe(proximos.body.meta.total);
    expect(grupo(avisos, 'MAINT_OVERDUE').total).toBe(2);
    expect(grupo(avisos, 'MAINT_UPCOMING').total).toBe(3);
  });

  it('test_el_administrador_tambien_recibe_las_citas_y_los_mantenimientos', async () => {
    await crearMantenimiento({ dias: 10 });
    await crearCita({ dia: 0 });

    const res = await consultar(admin);

    expect(res.body.data.groups.map((g) => g.type)).toEqual(['APPT_TODAY', 'MAINT_UPCOMING']);
  });
});
