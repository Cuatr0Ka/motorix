import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from '@jest/globals';
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

const ENV_KEYS = ['MAINTENANCE_WARN_DAYS', 'MAINTENANCE_WARN_KM'];
let envOriginal;

const hoyMas = (dias) => new Date(Date.now() + dias * 24 * 3600 * 1000);

/** Mantenimiento pendiente de un vehículo nuevo con kilometraje actual de 1 000. */
async function crearMantenimiento({ dias = null, dueMileage = null, descripcion }) {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `MAR-${String(seq).padStart(3, '0')}-Z`, currentMileage: 1000 });
  const orden = await createFinishedOrder(vehicle.id, recepcion.id, mecanico.id, { status: 'ENTREGADO', entryMileage: 0 });
  return createMaintenance(vehicle.id, orden.id, mecanico.id, {
    description: descripcion ?? `Servicio ${seq}`,
    dueDate: dias === null ? null : hoyMas(dias),
    dueMileage,
  });
}

const margenes = (cuerpo) => request(app).put('/api/settings').set(auth(admin.token)).send({ maintenance: cuerpo });
const indicador = async (id) => {
  const res = await request(app).get('/api/maintenance').set(auth(recepcion.token));
  return res.body.data.find((m) => m.id === id)?.indicator;
};
const panel = async () => (await request(app).get('/api/dashboard').set(auth(admin.token))).body.data.maintenance;
const avisos = async () => {
  const res = await request(app).get('/api/notifications').set(auth(recepcion.token));
  const total = (tipo) => res.body.data.groups.find((g) => g.type === tipo)?.total ?? 0;
  return { upcoming: total('MAINT_UPCOMING'), overdue: total('MAINT_OVERDUE') };
};
const porAvisar = async () => {
  const res = await request(app).get('/api/client-notices').set(auth(recepcion.token));
  return res.body.data.filter((fila) => fila.reason === 'MAINT_UPCOMING').length;
};

beforeEach(async () => {
  seq = 0;
  envOriginal = Object.fromEntries(ENV_KEYS.map((clave) => [clave, process.env[clave]]));
  for (const clave of ENV_KEYS) delete process.env[clave];
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

afterEach(() => {
  for (const clave of ENV_KEYS) {
    if (envOriginal[clave] === undefined) delete process.env[clave];
    else process.env[clave] = envOriginal[clave];
  }
});

describe('márgenes de «Próximo» configurables (US2, FR-003 y FR-004)', () => {
  it('test_un_margen_en_dias_menor_deja_de_clasificar_como_proximo_en_los_cuatro_lugares', async () => {
    const m = await crearMantenimiento({ dias: 20 });

    // Con el margen predeterminado (30 días) está a 20 días: Próximo en la lista, el panel, los avisos y los clientes.
    expect(await indicador(m.id)).toBe('PROXIMO');
    expect((await panel()).upcoming).toBe(1);
    expect((await avisos()).upcoming).toBe(1);
    expect(await porAvisar()).toBe(1);

    const res = await margenes({ warnDays: 15 });
    expect(res.status).toBe(200);
    expect(res.body.data.maintenance.warnDays).toBe(15);

    expect(await indicador(m.id)).toBe('NORMAL');
    expect((await panel()).upcoming).toBe(0);
    expect((await avisos()).upcoming).toBe(0);
    expect(await porAvisar()).toBe(0);
  });

  it('test_un_margen_en_dias_mayor_hace_que_un_mantenimiento_lejano_sea_proximo', async () => {
    const m = await crearMantenimiento({ dias: 45 });
    expect(await indicador(m.id)).toBe('NORMAL');

    await margenes({ warnDays: 60 });

    expect(await indicador(m.id)).toBe('PROXIMO');
    expect((await panel()).upcoming).toBe(1);
    expect((await avisos()).upcoming).toBe(1);
  });

  it('test_el_margen_en_kilometros_tambien_se_respeta_en_los_cuatro_lugares', async () => {
    // Kilometraje actual 1 000; objetivo 1 900: faltan 900 km, Próximo con el margen de 1 000.
    const m = await crearMantenimiento({ dueMileage: 1900 });
    expect(await indicador(m.id)).toBe('PROXIMO');

    await margenes({ warnKm: 500 });

    expect(await indicador(m.id)).toBe('NORMAL');
    expect((await panel()).upcoming).toBe(0);
    expect((await avisos()).upcoming).toBe(0);
    expect(await porAvisar()).toBe(0);
  });

  it('test_los_tres_lugares_coinciden_entre_si_con_varios_mantenimientos_y_un_margen_nuevo', async () => {
    for (const dias of [-3, 5, 10, 18, 25, 40]) await crearMantenimiento({ dias });
    await margenes({ warnDays: 20 });

    const delPanel = await panel();
    const deAvisos = await avisos();
    const lista = await request(app).get('/api/maintenance?indicator=PROXIMO').set(auth(recepcion.token));

    expect(delPanel.upcoming).toBe(3);
    expect(deAvisos.upcoming).toBe(3);
    expect(lista.body.meta.total).toBe(3);
    expect(delPanel.overdue).toBe(1);
    expect(deAvisos.overdue).toBe(1);
  });

  it('test_rechaza_margenes_fuera_de_limites_o_no_numericos', async () => {
    const invalidos = [
      { warnDays: 0 },
      { warnDays: -5 },
      { warnDays: 366 },
      { warnDays: 'treinta' },
      { warnDays: 12.5 },
      { warnKm: 0 },
      { warnKm: -1 },
      { warnKm: 100001 },
      { warnKm: '1000 km' },
    ];
    for (const cuerpo of invalidos) {
      const res = await margenes(cuerpo);
      expect({ cuerpo, estado: res.status }).toEqual({ cuerpo, estado: 400 });
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect((await request(app).get('/api/settings').set(auth(admin.token))).body.data.maintenance).toEqual({ warnDays: 30, warnKm: 1000 });
  });

  it('test_acepta_los_limites_exactos', async () => {
    expect((await margenes({ warnDays: 1, warnKm: 1 })).status).toBe(200);
    expect((await margenes({ warnDays: 365, warnKm: 100000 })).status).toBe(200);
  });

  it('test_sin_valores_guardados_usa_las_variables_de_entorno_y_sin_ellas_30_dias_y_1000_km', async () => {
    const m = await crearMantenimiento({ dias: 20 });
    expect(await indicador(m.id)).toBe('PROXIMO'); // predeterminado: 30 días

    process.env.MAINTENANCE_WARN_DAYS = '10';
    expect(await indicador(m.id)).toBe('NORMAL'); // el respaldo de entorno manda mientras no haya valor guardado

    await margenes({ warnDays: 25 });
    expect(await indicador(m.id)).toBe('PROXIMO'); // el valor guardado gana
  });

  it('test_una_variable_de_entorno_invalida_no_rompe_el_sistema_y_usa_el_predeterminado', async () => {
    process.env.MAINTENANCE_WARN_DAYS = 'abc';
    const m = await crearMantenimiento({ dias: 20 });

    expect(await indicador(m.id)).toBe('PROXIMO');
    const config = await request(app).get('/api/settings').set(auth(admin.token));
    expect(config.body.data.sources['maintenance.warn_days']).toBe('DEFAULT');
  });

  it('test_registrar_un_mantenimiento_nuevo_usa_el_margen_guardado_en_la_respuesta', async () => {
    await margenes({ warnDays: 10 });
    const orden = await createFinishedOrder(
      (await createClientWithVehicle({ licensePlate: 'MAR-900-Z', currentMileage: 1000 })).vehicle.id,
      recepcion.id,
      mecanico.id,
      { status: 'TERMINADO', entryMileage: 0 },
    );
    const fecha = hoyMas(20).toISOString().slice(0, 10);

    const res = await request(app)
      .post(`/api/orders/${orden.id}/maintenance`)
      .set(auth(mecanico.token))
      .send({ description: 'Afinación', dueDate: fecha });

    expect(res.status).toBe(201);
    expect(res.body.data.indicator).toBe('NORMAL'); // a 20 días con un margen de 10
  });
});
