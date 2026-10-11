import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { getMaintenanceConfig } from '../../config/env.js';
import { computeIndicator } from '../../services/maintenanceStatus.js';
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

/** Vehículo con un mantenimiento pendiente (fecha y/o kilometraje objetivo) y un kilometraje actual. */
async function crearCaso({ cliente, placa, current, dueDate = null, dueMileage = null, status = 'PENDIENTE', descripcion }) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle(
    { licensePlate: placa ?? `LST-${String(seq).padStart(3, '0')}-Z`, currentMileage: current },
    cliente ? { name: cliente } : {},
  );
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  return createMaintenance(vehicle.id, orden.id, mecanico.id, {
    description: descripcion ?? `Servicio ${seq}`,
    dueDate: dueDate === null ? null : hoyMas(dueDate),
    dueMileage,
    status,
  });
}

const listar = (user, q = '') => request(app).get(`/api/maintenance${q}`).set(auth(user.token));
const descripciones = (res) => res.body.data.map((m) => m.description);

beforeEach(async () => {
  seq = 0;
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('lista de mantenimientos con indicador calculado (US5, CA-3)', () => {
  it('test_clasifica_normal_proximo_y_vencido_por_fecha_por_kilometraje_y_por_ambos', async () => {
    await crearCaso({ descripcion: 'Vencido por fecha', current: 1000, dueDate: -5 });
    await crearCaso({ descripcion: 'Vencido por km', current: 60000, dueMileage: 60000 });
    await crearCaso({ descripcion: 'Vencido por una de dos', current: 90000, dueDate: 200, dueMileage: 80000 });
    await crearCaso({ descripcion: 'Próximo por fecha', current: 1000, dueDate: 12 });
    await crearCaso({ descripcion: 'Próximo por km', current: 59500, dueMileage: 60000 });
    await crearCaso({ descripcion: 'Normal por fecha', current: 1000, dueDate: 120 });
    await crearCaso({ descripcion: 'Normal por km', current: 1000, dueMileage: 20000 });
    await crearCaso({ descripcion: 'Normal por ambos', current: 1000, dueDate: 200, dueMileage: 30000 });

    const res = await listar(recepcion);
    const porNombre = Object.fromEntries(res.body.data.map((m) => [m.description, m.indicator]));

    expect(res.status).toBe(200);
    expect(porNombre).toEqual({
      'Vencido por fecha': 'VENCIDO',
      'Vencido por km': 'VENCIDO',
      'Vencido por una de dos': 'VENCIDO',
      'Próximo por fecha': 'PROXIMO',
      'Próximo por km': 'PROXIMO',
      'Normal por fecha': 'NORMAL',
      'Normal por km': 'NORMAL',
      'Normal por ambos': 'NORMAL',
    });
  });

  it('test_ordena_vencidos_proximos_y_normales_y_dentro_de_cada_grupo_por_fecha', async () => {
    await crearCaso({ descripcion: 'N2', current: 1, dueDate: 150 });
    await crearCaso({ descripcion: 'N1', current: 1, dueDate: 100 });
    await crearCaso({ descripcion: 'P1', current: 1, dueDate: 20 });
    await crearCaso({ descripcion: 'V2', current: 1, dueDate: -1 });
    await crearCaso({ descripcion: 'V1', current: 1, dueDate: -10 });

    const res = await listar(admin);

    expect(descripciones(res)).toEqual(['V1', 'V2', 'P1', 'N1', 'N2']);
  });

  it('test_incluye_cliente_y_telefono_para_recepcion_y_administracion', async () => {
    await crearCaso({ cliente: 'Ana Morales', placa: 'ANA-001-A', current: 100, dueDate: 5 });

    const res = await listar(recepcion);

    expect(res.body.data[0]).toMatchObject({
      client: { name: 'Ana Morales', phone: expect.any(String) },
      vehicle: { licensePlate: 'ANA-001-A', currentMileage: 100 },
      orderFolio: expect.stringMatching(/^OS-\d{6}$/),
      status: 'PENDIENTE',
    });
  });

  it('test_filtra_por_indicador', async () => {
    await crearCaso({ descripcion: 'V', current: 1, dueDate: -3 });
    await crearCaso({ descripcion: 'P', current: 1, dueDate: 10 });
    await crearCaso({ descripcion: 'N', current: 1, dueDate: 300 });

    expect(descripciones(await listar(admin, '?indicator=VENCIDO'))).toEqual(['V']);
    expect(descripciones(await listar(admin, '?indicator=PROXIMO'))).toEqual(['P']);
    expect(descripciones(await listar(admin, '?indicator=NORMAL'))).toEqual(['N']);
    expect((await listar(admin, '?indicator=ENORME')).status).toBe(400);
  });

  it('test_busca_por_cliente_o_placa', async () => {
    await crearCaso({ descripcion: 'A', cliente: 'Ana Morales', placa: 'AAA-111-A', current: 1, dueDate: 5 });
    await crearCaso({ descripcion: 'B', cliente: 'Luis Pérez', placa: 'BBB-222-B', current: 1, dueDate: 5 });

    expect(descripciones(await listar(recepcion, '?search=morales'))).toEqual(['A']);
    expect(descripciones(await listar(recepcion, '?search=BBB-222'))).toEqual(['B']);
    expect(descripciones(await listar(recepcion, '?search=nadie'))).toEqual([]);
  });

  it('test_los_atendidos_no_aparecen_por_defecto_pero_si_con_el_estado_atendido', async () => {
    await crearCaso({ descripcion: 'Pendiente', current: 1, dueDate: 5 });
    await crearCaso({ descripcion: 'Atendido', current: 1, dueDate: 5, status: 'ATENDIDO' });

    const pendientes = await listar(admin);
    const atendidos = await listar(admin, '?status=ATENDIDO');

    expect(descripciones(pendientes)).toEqual(['Pendiente']);
    expect(descripciones(atendidos)).toEqual(['Atendido']);
    expect(atendidos.body.data[0].indicator).toBeNull();
  });

  it('test_un_vehiculo_sin_kilometraje_solo_se_evalua_por_fecha', async () => {
    await crearCaso({ descripcion: 'Sin km', current: null, dueDate: 300, dueMileage: 100 });

    const res = await listar(admin);

    expect(res.body.data[0].indicator).toBe('NORMAL');
  });

  it('test_el_kilometraje_que_cambia_despues_de_programar_vuelve_vencido_el_mantenimiento', async () => {
    const m = await crearCaso({ descripcion: 'Cambia', current: 1000, dueMileage: 5000 });
    expect((await listar(admin)).body.data[0].indicator).toBe('NORMAL');

    await query('UPDATE vehicles SET current_mileage = 5200 WHERE id = ?', [m.vehicleId]);

    expect((await listar(admin)).body.data[0].indicator).toBe('VENCIDO');
  });

  it('test_pagina_los_resultados', async () => {
    for (let i = 0; i < 5; i += 1) await crearCaso({ descripcion: `M${i}`, current: 1, dueDate: 100 + i });

    const primera = await listar(admin, '?page=1&pageSize=2');
    const ultima = await listar(admin, '?page=3&pageSize=2');

    expect(primera.body.data).toHaveLength(2);
    expect(ultima.body.data).toHaveLength(1);
    expect(primera.body.meta).toEqual({ page: 1, pageSize: 2, total: 5 });
  });

  it('test_el_sql_de_filtro_coincide_con_la_funcion_pura_para_todas_las_combinaciones', async () => {
    const fechas = [null, -3, 0, 15, 30, 31, 200];
    const objetivos = [null, 900, 1000, 1500, 2000, 9000];
    for (const dueDate of fechas) {
      for (const dueMileage of objetivos) {
        if (dueDate === null && dueMileage === null) continue;
        await crearCaso({ descripcion: `${dueDate}|${dueMileage}`, current: 1000, dueDate, dueMileage });
      }
    }
    const { warnDays, warnKm } = getMaintenanceConfig();

    const res = await listar(admin, '?pageSize=100');

    expect(res.body.data).toHaveLength(fechas.length * objetivos.length - 1);
    for (const m of res.body.data) {
      const esperado = computeIndicator({
        dueDate: m.dueDate,
        dueMileage: m.dueMileage,
        currentMileage: m.vehicle.currentMileage,
        today: new Date(),
        warnDays,
        warnKm,
      });
      expect([m.description, m.indicator]).toEqual([m.description, esperado]);
    }
    // Y el filtro por indicador devuelve exactamente los mismos grupos.
    for (const indicador of ['VENCIDO', 'PROXIMO', 'NORMAL']) {
      const filtrado = await listar(admin, `?pageSize=100&indicator=${indicador}`);
      const esperados = res.body.data.filter((m) => m.indicator === indicador).map((m) => m.id).sort((a, b) => a - b);
      expect(filtrado.body.data.map((m) => m.id).sort((a, b) => a - b)).toEqual(esperados);
    }
  });
});

describe('permisos de la lista', () => {
  it('test_el_mecanico_recibe_403_y_sin_sesion_401', async () => {
    const mec = await listar(mecanico);
    const sinSesion = await request(app).get('/api/maintenance');

    expect(mec.status).toBe(403);
    expect(sinSesion.status).toBe(401);
  });

  it('test_la_lista_respeta_los_margenes_del_entorno', async () => {
    await crearCaso({ descripcion: 'A 45 días', current: 1, dueDate: 45 });
    const anterior = process.env.MAINTENANCE_WARN_DAYS;
    process.env.MAINTENANCE_WARN_DAYS = '60';
    try {
      const res = await listar(admin);
      expect(res.body.data[0].indicator).toBe('PROXIMO');
    } finally {
      if (anterior === undefined) delete process.env.MAINTENANCE_WARN_DAYS;
      else process.env.MAINTENANCE_WARN_DAYS = anterior;
    }
    expect((await listar(admin)).body.data[0].indicator).toBe('NORMAL');
  });
});
