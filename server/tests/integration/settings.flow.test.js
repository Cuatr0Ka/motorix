import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const ENV_KEYS = ['SHOP_NAME', 'SHOP_ADDRESS', 'SHOP_PHONE', 'SHOP_EMAIL', 'MAINTENANCE_WARN_DAYS', 'MAINTENANCE_WARN_KM'];
let envOriginal;

const leer = (user = admin) => request(app).get('/api/settings').set(auth(user.token));
const guardar = (cuerpo, user = admin) => request(app).put('/api/settings').set(auth(user.token)).send(cuerpo);

/** Orden cobrada y con ticket generado, de un vehículo nuevo. */
let seq = 0;
async function ticketNuevo() {
  seq += 1;
  const { vehicle } = await createClientWithVehicle({ licensePlate: `SET-${String(seq).padStart(3, '0')}-Z` });
  const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
  const res = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));
  return res;
}

beforeEach(async () => {
  seq = 0;
  envOriginal = Object.fromEntries(ENV_KEYS.map((clave) => [clave, process.env[clave]]));
  for (const clave of ENV_KEYS) delete process.env[clave];
  setGateway(new FakeGateway({ configured: true }));
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

afterEach(() => {
  resetGateway();
  for (const clave of ENV_KEYS) {
    if (envOriginal[clave] === undefined) delete process.env[clave];
    else process.env[clave] = envOriginal[clave];
  }
});

describe('configuración del taller (US1, FR-001 a FR-003, FR-008)', () => {
  it('test_sin_valores_guardados_ni_variables_usa_los_predeterminados', async () => {
    const res = await leer();

    expect(res.status).toBe(200);
    expect(res.body.data.shop).toEqual({ name: 'Motorix Taller Mecánico', address: '', phone: '', email: '' });
    expect(res.body.data.maintenance).toEqual({ warnDays: 30, warnKm: 1000 });
    expect(res.body.data.sources).toEqual({
      'shop.name': 'DEFAULT',
      'shop.address': 'DEFAULT',
      'shop.phone': 'DEFAULT',
      'shop.email': 'DEFAULT',
      'maintenance.warn_days': 'DEFAULT',
      'maintenance.warn_km': 'DEFAULT',
    });
  });

  it('test_sin_valores_guardados_usa_las_variables_de_entorno_de_respaldo', async () => {
    process.env.SHOP_NAME = 'Taller del Norte';
    process.env.SHOP_ADDRESS = 'Calle 5 #10';
    process.env.SHOP_PHONE = '7760001122';
    process.env.SHOP_EMAIL = 'taller@norte.mx';
    process.env.MAINTENANCE_WARN_DAYS = '20';
    process.env.MAINTENANCE_WARN_KM = '800';

    const res = await leer();

    expect(res.body.data.shop).toEqual({ name: 'Taller del Norte', address: 'Calle 5 #10', phone: '7760001122', email: 'taller@norte.mx' });
    expect(res.body.data.maintenance).toEqual({ warnDays: 20, warnKm: 800 });
    expect(Object.values(res.body.data.sources)).toEqual(['ENV', 'ENV', 'ENV', 'ENV', 'ENV', 'ENV']);
  });

  it('test_guardar_solo_cambia_los_campos_enviados_y_marca_su_origen_como_guardado', async () => {
    process.env.SHOP_ADDRESS = 'Dirección de respaldo';

    const res = await guardar({ shop: { name: 'Taller Los Pinos', phone: '7761112233' } });

    expect(res.status).toBe(200);
    expect(res.body.data.shop).toEqual({ name: 'Taller Los Pinos', address: 'Dirección de respaldo', phone: '7761112233', email: '' });
    expect(res.body.data.maintenance).toEqual({ warnDays: 30, warnKm: 1000 });
    expect(res.body.data.sources['shop.name']).toBe('STORED');
    expect(res.body.data.sources['shop.phone']).toBe('STORED');
    expect(res.body.data.sources['shop.address']).toBe('ENV');
    const otra = await leer();
    expect(otra.body.data).toEqual(res.body.data);
  });

  it('test_el_valor_guardado_gana_sobre_la_variable_de_entorno', async () => {
    process.env.SHOP_NAME = 'Nombre de respaldo';

    await guardar({ shop: { name: 'Nombre guardado' } });
    const res = await leer();

    expect(res.body.data.shop.name).toBe('Nombre guardado');
    expect(res.body.data.sources['shop.name']).toBe('STORED');
  });

  it('test_se_puede_dejar_la_direccion_vacia', async () => {
    await guardar({ shop: { address: 'Calle 1' } });

    const res = await guardar({ shop: { address: '' } });

    expect(res.status).toBe(200);
    expect(res.body.data.shop.address).toBe('');
    expect(res.body.data.sources['shop.address']).toBe('STORED');
  });

  it('test_rechaza_datos_invalidos_indicando_el_campo', async () => {
    const casos = [
      [{ shop: { name: '' } }, 'name'],
      [{ shop: { name: 'x'.repeat(101) } }, 'name'],
      [{ shop: { address: 'x'.repeat(201) } }, 'address'],
      [{ shop: { phone: 'x'.repeat(21) } }, 'phone'],
      [{ shop: { phone: 'llamar al taller' } }, 'phone'],
      [{ shop: { email: 'sin-arroba' } }, 'email'],
      [{ shop: { email: 'a'.repeat(250) + '@x.mx' } }, 'email'],
    ];
    for (const [cuerpo, campo] of casos) {
      const res = await guardar(cuerpo);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(JSON.stringify(res.body.error.details)).toContain(campo);
    }
    expect((await query('SELECT * FROM settings')).length).toBe(0);
  });

  it('test_rechaza_un_cuerpo_vacio_o_con_campos_desconocidos', async () => {
    expect((await guardar({})).status).toBe(400);
    expect((await guardar({ shop: {} })).status).toBe(400);
    expect((await guardar({ shop: { name: 'Taller', color: 'rojo' } })).status).toBe(400);
    expect((await guardar({ otra: 1 })).status).toBe(400);
  });

  it('test_un_ticket_nuevo_usa_los_datos_vigentes_y_uno_anterior_conserva_los_suyos', async () => {
    await guardar({ shop: { name: 'Taller Uno', address: 'Calle Uno 1', phone: '7761000001' } });
    const antes = await ticketNuevo();
    expect(antes.status).toBe(201);
    expect(antes.body.data.ticket.content.shop).toEqual({ name: 'Taller Uno', address: 'Calle Uno 1', phone: '7761000001' });

    await guardar({ shop: { name: 'Taller Dos', address: 'Calle Dos 2', phone: '7762000002' } });
    const despues = await ticketNuevo();
    expect(despues.body.data.ticket.content.shop).toEqual({ name: 'Taller Dos', address: 'Calle Dos 2', phone: '7762000002' });

    const anterior = await request(app).get(`/api/tickets/${antes.body.data.ticket.id}`).set(auth(recepcion.token));
    expect(anterior.body.data.content.shop).toEqual({ name: 'Taller Uno', address: 'Calle Uno 1', phone: '7761000001' });
  });

  it('test_el_cambio_queda_en_la_bitacora_como_cambio_de_configuracion', async () => {
    await guardar({ shop: { name: 'Taller Nuevo' }, maintenance: { warnDays: 15 } });

    const filas = await query("SELECT actor_user_id, action, entity_type, summary FROM audit_log WHERE action = 'SETTINGS_CHANGED'");

    expect(filas).toHaveLength(1);
    expect(filas[0].actor_user_id).toBe(admin.id);
    expect(filas[0].entity_type).toBe('settings');
    expect(filas[0].summary).toContain('nombre');
    expect(filas[0].summary).toContain('30 → 15');
  });

  it('test_dos_cambios_simultaneos_no_dejan_datos_a_medias_y_ambos_quedan_en_la_bitacora', async () => {
    const [uno, dos] = await Promise.all([
      guardar({ shop: { name: 'Taller A', address: 'Dirección A', phone: '7761111111' } }),
      guardar({ shop: { name: 'Taller B', address: 'Dirección B', phone: '7762222222' } }),
    ]);

    expect(uno.status).toBe(200);
    expect(dos.status).toBe(200);
    const final = (await leer()).body.data.shop;
    // Gana el último cambio y los tres campos de una misma solicitud no se mezclan con los de la otra.
    const sufijo = final.name.slice(-1);
    expect(final).toEqual({
      name: `Taller ${sufijo}`,
      address: `Dirección ${sufijo}`,
      phone: sufijo === 'A' ? '7761111111' : '7762222222',
      email: '',
    });
    expect((await query("SELECT id FROM audit_log WHERE action = 'SETTINGS_CHANGED'")).length).toBe(2);
  });

  it('test_la_recepcion_y_el_mecanico_reciben_403_al_ver_y_al_cambiar', async () => {
    for (const usuario of [recepcion, mecanico]) {
      expect((await leer(usuario)).status).toBe(403);
      expect((await guardar({ shop: { name: 'Otro taller' } }, usuario)).status).toBe(403);
    }
    expect((await query('SELECT * FROM settings')).length).toBe(0);
  });

  it('test_sin_token_responde_401', async () => {
    expect((await request(app).get('/api/settings')).status).toBe(401);
    expect((await request(app).put('/api/settings').send({ shop: { name: 'X' } })).status).toBe(401);
  });
});
