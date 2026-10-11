import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createOrder, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { readStandardPasswords, runSeedFile } from '../helpers/seed.js';

const app = createApp();
const contar = async (tabla) => Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total);
const sembrar = async () => {
  await runSeedFile('001_initial_data.sql');
  await runSeedFile('002_appointments_orders.sql');
};
const conteos = async () =>
  Promise.all(['users', 'clients', 'vehicles', 'appointments', 'service_orders', 'order_services', 'order_labor', 'order_status_history'].map(contar));

beforeEach(resetDatabase);

describe('seed del Sprint 2 (FR-026, SC-009)', () => {
  it('test_crea_el_segundo_mecanico_y_citas_en_los_cinco_estados', async () => {
    await sembrar();

    const usuarios = (await query('SELECT username, role FROM users ORDER BY username')).map((u) => `${u.username}:${u.role}`);
    expect(usuarios).toEqual(['admin:ADMIN', 'mecanico:MECHANIC', 'mecanico2:MECHANIC', 'recepcion:RECEPTIONIST']);

    const estados = (await query('SELECT DISTINCT status FROM appointments')).map((c) => c.status).sort();
    expect(estados).toEqual(['CANCELADA', 'COMPLETADA', 'CONFIRMADA', 'EN_PROCESO', 'PENDIENTE']);
    const futuras = await query("SELECT status FROM appointments WHERE scheduled_at > NOW() AND status IN ('PENDIENTE','CONFIRMADA')");
    expect(futuras.map((c) => c.status).sort()).toEqual(['CONFIRMADA', 'PENDIENTE']);
    const [cancelada] = await query("SELECT cancel_reason, cancelled_at FROM appointments WHERE status = 'CANCELADA'");
    expect(cancelada.cancel_reason).toBeTruthy();
    expect(cancelada.cancelled_at).not.toBeNull();
  });

  it('test_crea_ordenes_en_los_seis_estados_repartidas_entre_los_dos_mecanicos', async () => {
    await sembrar();

    const estados = (await query('SELECT DISTINCT status FROM service_orders')).map((o) => o.status).sort();
    expect(estados).toEqual(['DIAGNOSTICO', 'ENTREGADO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'RECIBIDO', 'TERMINADO']);
    expect(await contar('service_orders')).toBeGreaterThanOrEqual(7);

    const porMecanico = await query(
      `SELECT u.username, COUNT(*) AS total FROM service_orders o JOIN users u ON u.id = o.mechanic_id GROUP BY u.username ORDER BY u.username`,
    );
    expect(porMecanico.map((m) => m.username)).toEqual(['mecanico', 'mecanico2']);
    for (const fila of porMecanico) expect(Number(fila.total)).toBeGreaterThanOrEqual(2);

    const sinAsignar = await query("SELECT status FROM service_orders WHERE mechanic_id IS NULL");
    expect(sinAsignar.map((o) => o.status)).toEqual(['RECIBIDO']);
    const entregadas = await query("SELECT delivered_at FROM service_orders WHERE status = 'ENTREGADO'");
    expect(entregadas).toHaveLength(2);
    for (const fila of entregadas) expect(fila.delivered_at).not.toBeNull();
  });

  it('test_es_coherente_cliente_vehiculo_kilometraje_historial_y_citas', async () => {
    await sembrar();

    const clientesIncoherentes = await query(
      'SELECT o.id FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id WHERE o.client_id <> v.client_id',
    );
    expect(clientesIncoherentes).toEqual([]);

    const abiertasPorVehiculo = await query(
      "SELECT vehicle_id FROM service_orders WHERE status <> 'ENTREGADO' GROUP BY vehicle_id HAVING COUNT(*) > 1",
    );
    expect(abiertasPorVehiculo).toEqual([]);

    // El kilometraje de entrada de una orden abierta no es menor al actual del vehículo (RN-4).
    const kilometrajeMenor = await query(
      "SELECT o.id FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id WHERE o.status <> 'ENTREGADO' AND v.current_mileage IS NOT NULL AND o.entry_mileage < v.current_mileage",
    );
    expect(kilometrajeMenor).toEqual([]);

    // El último cambio del historial coincide con el estado actual de cada orden.
    const historialDesfasado = await query(
      `SELECT o.id FROM service_orders o
        WHERE (SELECT h.to_status FROM order_status_history h WHERE h.order_id = o.id ORDER BY h.changed_at DESC, h.id DESC LIMIT 1) <> o.status
           OR NOT EXISTS (SELECT 1 FROM order_status_history h WHERE h.order_id = o.id)`,
    );
    expect(historialDesfasado).toEqual([]);

    // Cita En proceso -> su orden está abierta; cita Completada -> su orden llegó a Terminado o Entregado.
    const enProceso = await query(
      "SELECT o.status FROM appointments a JOIN service_orders o ON o.appointment_id = a.id WHERE a.status = 'EN_PROCESO'",
    );
    expect(enProceso).toHaveLength(1);
    expect(enProceso[0].status).not.toBe('ENTREGADO');
    const completadas = await query(
      "SELECT o.status FROM appointments a JOIN service_orders o ON o.appointment_id = a.id WHERE a.status = 'COMPLETADA'",
    );
    expect(completadas.map((o) => o.status)).toEqual(['TERMINADO']);
  });

  it('test_cada_mecanico_ve_solo_sus_ordenes_con_las_contrasenas_documentadas', async () => {
    await sembrar();
    const contrasenas = readStandardPasswords();
    const placasDe = async (usuario) => {
      const login = await request(app).post('/api/auth/login').send({ identifier: usuario, password: contrasenas[usuario] });
      expect(login.status).toBe(200);
      const res = await request(app).get('/api/orders').set(auth(login.body.data.token));
      return res.body.data.map((o) => o.vehicle.licensePlate).sort();
    };

    expect(await placasDe('mecanico')).toEqual(['ABC-123-A', 'GHI-789-C']);
    expect(await placasDe('mecanico2')).toEqual(['DEF-456-B', 'STU-901-G']);
  });

  it('test_los_totales_de_una_orden_sembrada_se_calculan_a_partir_de_sus_lineas', async () => {
    await sembrar();
    const [orden] = await query("SELECT o.id FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id WHERE v.license_plate = 'STU-901-G'");
    const admin = await createUserWithToken('ADMIN');

    const res = await request(app).get(`/api/orders/${orden.id}`).set(auth(admin.token));

    expect(res.body.data.totals).toEqual({ services: '1870.00', labor: '700.00', total: '2570.00' });
    expect(res.body.data.statusHistory.map((c) => c.toStatus)).toEqual(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO']);
  });

  it('test_las_ordenes_de_ejemplo_coinciden_con_el_flujo_de_transiciones', async () => {
    await sembrar();
    const { allowedNext } = await import('../../services/orderTransitions.js');

    const saltos = await query('SELECT from_status, to_status FROM order_status_history WHERE from_status IS NOT NULL');
    for (const salto of saltos) expect(allowedNext(salto.from_status)).toContain(salto.to_status);
  });
});

describe('idempotencia del seed del Sprint 2', () => {
  it('test_repetirlo_no_duplica_ningun_registro', async () => {
    await sembrar();
    const antes = await conteos();

    await runSeedFile('002_appointments_orders.sql');
    await runSeedFile('002_appointments_orders.sql');
    await sembrar();

    expect(await conteos()).toEqual(antes);
    const huerfanos = await query(
      `SELECT (SELECT COUNT(*) FROM order_services s LEFT JOIN service_orders o ON o.id = s.order_id WHERE o.id IS NULL)
            + (SELECT COUNT(*) FROM order_labor s LEFT JOIN service_orders o ON o.id = s.order_id WHERE o.id IS NULL) AS total`,
    );
    expect(Number(huerfanos[0].total)).toBe(0);
  });

  it('test_no_pisa_una_orden_abierta_creada_a_mano_ni_falla', async () => {
    await runSeedFile('001_initial_data.sql');
    const recepcion = await createUserWithToken('RECEPTIONIST');
    const [vehiculo] = await query("SELECT id FROM vehicles WHERE license_plate = 'BCD-890-K'");
    const manual = await createOrder(vehiculo.id, recepcion.id, { reportedProblem: 'Orden creada a mano', entryMileage: 30000 });

    await expect(runSeedFile('002_appointments_orders.sql')).resolves.not.toThrow();

    const delVehiculo = await query('SELECT id, reported_problem FROM service_orders WHERE vehicle_id = ?', [vehiculo.id]);
    expect(delVehiculo).toEqual([{ id: manual.id, reported_problem: 'Orden creada a mano' }]);
  });

  it('test_no_restablece_la_contrasena_de_mecanico2_si_ya_la_cambio', async () => {
    await sembrar();
    await query("UPDATE users SET password_hash = 'hash-cambiado' WHERE username = 'mecanico2'");

    await runSeedFile('002_appointments_orders.sql');

    const [fila] = await query("SELECT password_hash FROM users WHERE username = 'mecanico2'");
    expect(fila.password_hash).toBe('hash-cambiado');
  });
});
