import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createLabor, createOrder, createService, createServiceType, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { DENTRO, PERIODO, fecharTerminada, nuevoVehiculo } from '../helpers/reports.js';

const app = createApp();
let admin;
let recepcion;
let mec1;
let mec2;
let vehiculo;

const pedir = (ruta, q = PERIODO, token = admin.token) => request(app).get(`/api/reports/${ruta}`).query(q).set(auth(token));

async function terminada(mecanico, fecha, { servicios = [], mano = [] } = {}) {
  const orden = await createOrder((await nuevoVehiculo()).id, recepcion.id, { mechanicId: mecanico?.id ?? null, status: 'TERMINADO' });
  for (const s of servicios) await createService(orden.id, s);
  for (const m of mano) await createLabor(orden.id, m);
  if (fecha) await fecharTerminada(orden.id, recepcion.id, fecha);
  return orden;
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mec1 = await createUserWithToken('MECHANIC', { name: 'Primer mecánico' });
  mec2 = await createUserWithToken('MECHANIC', { name: 'Segundo mecánico' });
  ({ vehicle: vehiculo } = await createClientWithVehicle({ licensePlate: 'OPE-001-A' }));
});

describe('servicios más frecuentes (US5, FR-020)', () => {
  it('test_cuenta_por_tipo_y_por_descripcion_de_mayor_a_menor_frecuencia', async () => {
    const aceite = await createServiceType({ name: 'Cambio de aceite' });
    const o1 = await terminada(mec1, DENTRO, { servicios: [{ description: 'Aceite sintético', amount: '500.00' }, { description: 'Balatas', amount: '850.00' }] });
    const o2 = await terminada(mec2, DENTRO, { servicios: [{ description: 'Aceite mineral', amount: '300.00' }] });
    await query('UPDATE order_services SET service_type_id = ? WHERE order_id IN (?, ?) AND description LIKE ?', [aceite.id, o1.id, o2.id, 'Aceite%']);

    const { data } = (await pedir('services')).body;

    expect(data.items[0]).toEqual({ name: 'Cambio de aceite', times: 2, amount: '800.00' });
    expect(data.items[1]).toEqual({ name: 'Balatas', times: 1, amount: '850.00' });
  });

  it('test_una_orden_terminada_fuera_del_rango_no_cuenta_y_un_periodo_vacio_da_lista_vacia', async () => {
    await terminada(mec1, '2026-09-30 23:00:00', { servicios: [{ description: 'Fuera', amount: '100.00' }] });

    expect((await pedir('services')).body.data.items).toEqual([]);
  });

  it('test_la_fecha_es_la_del_ultimo_cambio_a_terminado', async () => {
    const orden = await terminada(mec1, '2026-09-10 10:00:00', { servicios: [{ description: 'Reabierta', amount: '100.00' }] });
    await fecharTerminada(orden.id, recepcion.id, DENTRO);

    expect((await pedir('services')).body.data.items).toHaveLength(1);
  });
});

describe('productividad por mecánico (US5, FR-020)', () => {
  it('test_da_por_mecanico_las_ordenes_terminadas_y_la_mano_de_obra', async () => {
    await terminada(mec1, DENTRO, { mano: [{ description: 'MO 1', amount: '100.10' }, { description: 'MO 2', amount: '200.20' }] });
    await terminada(mec1, DENTRO, { mano: [{ description: 'MO 3', amount: '50.00' }] });
    await terminada(mec2, DENTRO, { mano: [{ description: 'MO 4', amount: '400.00' }] });

    const { data } = (await pedir('productivity')).body;

    expect(data.items).toEqual([
      { mechanicId: mec1.id, name: 'Primer mecánico', ordersFinished: 2, laborAmount: '350.30' },
      { mechanicId: mec2.id, name: 'Segundo mecánico', ordersFinished: 1, laborAmount: '400.00' },
    ]);
  });

  it('test_una_orden_sin_mecanico_no_se_atribuye_a_nadie_y_fuera_del_rango_no_cuenta', async () => {
    await terminada(null, DENTRO, { mano: [{ description: 'MO', amount: '100.00' }] });
    await terminada(mec1, '2026-11-02 10:00:00', { mano: [{ description: 'MO', amount: '100.00' }] });

    expect((await pedir('productivity')).body.data.items).toEqual([]);
  });
});

describe('permisos de los reportes de operación', () => {
  it('test_recepcion_y_mecanico_reciben_403', async () => {
    for (const ruta of ['services', 'productivity']) {
      for (const u of [recepcion, mec1]) expect((await pedir(ruta, PERIODO, u.token)).status).toBe(403);
    }
  });
});
