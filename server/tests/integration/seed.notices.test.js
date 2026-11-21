import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const app = createApp();
let admin;
let recepcion;

const ANTERIORES = [
  '001_initial_data.sql',
  '002_appointments_orders.sql',
  '003_history_inventory.sql',
  '004_payments_tickets.sql',
  '005_part_prices.sql',
];
const SEED_6 = '006_notices.sql';

const sembrarTodo = async () => {
  for (const archivo of ANTERIORES) await runSeedFile(archivo);
  await runSeedFile(SEED_6);
};

const TABLAS = ['appointments', 'service_orders', 'order_status_history', 'client_notices', 'notification_reads', 'maintenance', 'parts'];
const conteos = async () =>
  Object.fromEntries(
    await Promise.all(TABLAS.map(async (tabla) => [tabla, Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total)])),
  );

const avisos = (user) => request(app).get('/api/notifications').set(auth(user.token));
const clientes = (user) => request(app).get('/api/client-notices').set(auth(user.token));
const tipos = (res) => res.body.data.groups.map((g) => g.type).sort();

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
});

describe('seed del Sprint 6: datos de ejemplo de notificaciones (FR-022, CA-12)', () => {
  it('test_es_idempotente_dos_ejecuciones_no_duplican_ningun_registro', async () => {
    await sembrarTodo();
    const primera = await conteos();

    await runSeedFile(SEED_6);
    await runSeedFile(SEED_6);

    expect(await conteos()).toEqual(primera);
  });

  it('test_el_centro_de_notificaciones_del_administrador_tiene_un_caso_de_cada_tipo', async () => {
    await sembrarTodo();

    const res = await avisos(admin);

    expect(res.status).toBe(200);
    expect(tipos(res)).toEqual(['APPT_TODAY', 'MAINT_OVERDUE', 'MAINT_UPCOMING', 'STALLED', 'STOCK_LOW', 'STOCK_OUT']);
    expect(res.body.data.unread).toBe(res.body.data.total);
  });

  it('test_la_recepcion_ve_mantenimientos_citas_y_ordenes_detenidas_pero_no_stock', async () => {
    await sembrarTodo();

    const res = await avisos(recepcion);

    expect(tipos(res)).toEqual(['APPT_TODAY', 'MAINT_OVERDUE', 'MAINT_UPCOMING', 'STALLED']);
  });

  it('test_la_orden_detenida_del_seed_esta_asignada_al_mecanico_sembrado', async () => {
    await sembrarTodo();

    const [orden] = await query(
      `SELECT u.username, o.status
         FROM service_orders o JOIN users u ON u.id = o.mechanic_id
        WHERE o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'`,
    );

    expect(orden).toEqual({ username: 'mecanico', status: 'EN_REPARACION' });
  });

  it('test_la_lista_de_clientes_por_avisar_tiene_un_caso_de_cada_motivo', async () => {
    await sembrarTodo();

    const res = await clientes(recepcion);

    expect(res.status).toBe(200);
    const motivos = [...new Set(res.body.data.map((fila) => fila.reason))].sort();
    expect(motivos).toEqual(['APPT_TOMORROW', 'MAINT_OVERDUE', 'MAINT_UPCOMING', 'ORDER_READY']);
  });

  it('test_el_aviso_ya_registrado_no_aparece_y_conserva_quien_avisó', async () => {
    await sembrarTodo();

    const registrados = await query(
      `SELECT n.reason, n.fact_id, u.username
         FROM client_notices n JOIN users u ON u.id = n.notified_by`,
    );
    const res = await clientes(admin);

    expect(registrados).toHaveLength(1);
    expect(registrados[0]).toMatchObject({ reason: 'ORDER_READY', username: 'recepcion' });
    const pendientesDeOrden = res.body.data.filter((f) => f.reason === 'ORDER_READY').map((f) => f.factId);
    expect(pendientesDeOrden).not.toContain(registrados[0].fact_id);
    expect(pendientesDeOrden.length).toBeGreaterThan(0);
  });

  it('test_la_orden_detenida_tiene_su_ultimo_cambio_de_estado_hace_mas_de_tres_dias', async () => {
    await sembrarTodo();

    const [fila] = await query(
      `SELECT o.status, MAX(h.changed_at) AS ultimo, COUNT(h.id) AS cambios
         FROM service_orders o JOIN order_status_history h ON h.order_id = o.id
        WHERE o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'
        GROUP BY o.id, o.status`,
    );

    expect(fila.status).toBe('EN_REPARACION');
    expect(Number(fila.cambios)).toBe(3);
    const dias = (Date.now() - new Date(fila.ultimo).getTime()) / (24 * 3600 * 1000);
    expect(dias).toBeGreaterThan(4);
  });

  it('test_no_toca_pagos_tickets_ni_ordenes_entregadas', async () => {
    await runSeedFile(ANTERIORES[0]);
    for (const archivo of ANTERIORES.slice(1)) await runSeedFile(archivo);
    const antes = {
      pagos: await query('SELECT id, amount, status FROM payments ORDER BY id'),
      tickets: await query('SELECT id, order_id, payment_id FROM tickets ORDER BY id'),
      entregadas: await query("SELECT id, status FROM service_orders WHERE status = 'ENTREGADO' ORDER BY id"),
    };

    await runSeedFile(SEED_6);

    expect(await query('SELECT id, amount, status FROM payments ORDER BY id')).toEqual(antes.pagos);
    expect(await query('SELECT id, order_id, payment_id FROM tickets ORDER BY id')).toEqual(antes.tickets);
    expect(await query("SELECT id, status FROM service_orders WHERE status = 'ENTREGADO' ORDER BY id")).toEqual(antes.entregadas);
  });
});
