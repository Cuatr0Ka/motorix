import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { loginAndAccept, resetDatabase } from '../helpers/factories.js';
import { readStandardPasswords, runSeedFile } from '../helpers/seed.js';

const app = createApp();
const SEEDS = ['001_initial_data.sql', '002_appointments_orders.sql', '003_history_inventory.sql', '004_payments_tickets.sql', '005_part_prices.sql', '006_notices.sql', '007_settings_service_types.sql'];

async function sembrar() {
  for (const archivo of SEEDS) await runSeedFile(archivo);
}

const conteo = async (tabla) => Number((await query(`SELECT COUNT(*) AS n FROM ${tabla}`))[0].n);

beforeEach(async () => {
  await resetDatabase();
});

describe('datos de ejemplo del Sprint 7 (SC-007)', () => {
  it('test_correr_el_seed_dos_veces_no_duplica_filas', async () => {
    await sembrar();
    const antes = { settings: await conteo('settings'), tipos: await conteo('service_types') };
    await runSeedFile('007_settings_service_types.sql');

    expect(antes).toEqual({ settings: 5, tipos: 5 });
    expect({ settings: await conteo('settings'), tipos: await conteo('service_types') }).toEqual(antes);
  });

  it('test_no_sobrescribe_un_valor_ya_guardado', async () => {
    await sembrar();
    await query("UPDATE settings SET setting_value = 'Mi Taller' WHERE setting_key = 'shop.name'");
    await runSeedFile('007_settings_service_types.sql');

    expect((await query("SELECT setting_value FROM settings WHERE setting_key = 'shop.name'"))[0].setting_value).toBe('Mi Taller');
  });

  it('test_la_configuracion_y_los_tipos_de_servicio_traen_datos_y_los_terminos_1_0_existen', async () => {
    await sembrar();
    const admin = await loginAndAccept(app, 'admin', readStandardPasswords().admin);
    const token = admin.body.data.token;
    const auth = { Authorization: `Bearer ${token}` };

    const config = await request(app).get('/api/settings').set(auth);
    expect(config.body.data).toMatchObject({ shop: { name: 'Motorix Taller Mecánico' }, maintenance: { warnDays: 30, warnKm: 1000 } });
    const tipos = await request(app).get('/api/service-types').set(auth);
    expect(tipos.body.meta.total).toBe(5);
    expect(tipos.body.data.map((t) => t.name)).toContain('Cambio de aceite');
    expect((await request(app).get('/api/terms/current').set(auth)).body.data.version).toBe('1.0');
  });

  it('test_los_reportes_de_un_periodo_amplio_traen_informacion_de_los_datos_sembrados', async () => {
    await sembrar();
    const admin = await loginAndAccept(app, 'admin', readStandardPasswords().admin);
    const auth = { Authorization: `Bearer ${admin.body.data.token}` };
    const ahora = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const hoy = `${ahora.getFullYear()}-${pad(ahora.getMonth() + 1)}-${pad(ahora.getDate())}`;
    const hace = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() - 300);
    const desde = `${hace.getFullYear()}-${pad(hace.getMonth() + 1)}-${pad(hace.getDate())}`;
    const pedir = (ruta) => request(app).get(`/api/reports/${ruta}`).query({ from: desde, to: hoy }).set(auth);

    for (const ruta of ['income', 'services', 'productivity', 'parts', 'rotation']) {
      expect((await pedir(ruta)).status).toBe(200);
    }
    const resumen = {
      servicios: (await pedir('services')).body.data.items.length,
      partes: (await pedir('parts')).body.data.items.length,
      rotacion: (await pedir('rotation')).body.data.items.length,
    };
    expect(resumen.servicios + resumen.partes + resumen.rotacion).toBeGreaterThan(0);
  });
});
