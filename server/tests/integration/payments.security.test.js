import request from 'supertest';
import { afterAll, afterEach, beforeEach, describe, expect, it, jest } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { createMercadoPagoGateway, resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  auth,
  createClientWithVehicle,
  createPayableOrder,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
const TOKEN = 'TEST-1234567890-token-secreto-de-prueba';
let recepcion;
let admin;
let mecanico;
let orden;
let salida;

/** Gateway real con un `fetch` simulado, para comprobar que el token no se filtra en ninguna salida. */
function gatewayConFetch(fetchImpl) {
  return createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: 'https://mp.simulado.local', fetchImpl });
}

const proveedorFeliz = () =>
  gatewayConFetch(async (url) => ({
    ok: true,
    status: 200,
    json: async () =>
      url.includes('/checkout/preferences')
        ? { init_point: 'https://real/x', sandbox_init_point: 'https://sandbox.mp.simulado/pay/abc' }
        : { results: [{ id: 55, status: 'approved', card: { last_four_digits: '1234', cardholder: { name: 'Persona' } } }] },
  }));

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  admin = await createUserWithToken('ADMIN');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'SEG-001-A' });
  orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  salida = [jest.spyOn(console, 'log'), jest.spyOn(console, 'error'), jest.spyOn(console, 'warn'), jest.spyOn(console, 'info')];
  for (const espia of salida) espia.mockImplementation(() => {});
});

afterEach(() => {
  for (const espia of salida) espia.mockRestore();
});

afterAll(() => resetGateway());

const textoEmitido = () => salida.flatMap((espia) => espia.mock.calls.map((llamada) => llamada.map(String).join(' '))).join('\n');

describe('sin datos de tarjeta ni credenciales en ninguna salida (SC-006, CA-3, CA-7)', () => {
  it('test_el_token_y_los_datos_de_tarjeta_del_proveedor_no_aparecen_en_respuestas_base_ni_consola', async () => {
    setGateway(proveedorFeliz());
    const respuestas = [];

    const creado = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });
    respuestas.push(creado);
    const consulta = await request(app).post(`/api/payments/${creado.body.data.id}/refresh`).set(auth(recepcion.token));
    respuestas.push(consulta);
    respuestas.push(await request(app).get('/api/payments').set(auth(recepcion.token)));
    respuestas.push(await request(app).get(`/api/payments/${creado.body.data.id}`).set(auth(admin.token)));
    respuestas.push(await request(app).get(`/api/orders/${orden.id}`).set(auth(recepcion.token)));
    respuestas.push(await request(app).get(`/api/orders/${orden.id}/payments`).set(auth(admin.token)));
    respuestas.push(await request(app).get('/api/payments/methods').set(auth(recepcion.token)));

    expect(creado.status).toBe(201);
    expect(consulta.body.data.status).toBe('PAGADO');
    for (const res of respuestas) {
      const texto = JSON.stringify(res.body);
      expect(texto).not.toContain(TOKEN);
      expect(texto).not.toContain('1234567890');
      expect(texto).not.toContain('last_four_digits');
      expect(texto).not.toContain('cardholder');
      expect(texto).not.toMatch(/Bearer/i);
    }
    const base = JSON.stringify(await query('SELECT * FROM payments'));
    expect(base).not.toContain(TOKEN);
    expect(base).not.toContain('last_four_digits');
    expect(base).not.toContain('cardholder');
    expect(textoEmitido()).not.toContain(TOKEN);
  });

  it('test_un_error_del_proveedor_no_reenvia_su_cuerpo_ni_el_token', async () => {
    setGateway(
      gatewayConFetch(async () => ({
        ok: false,
        status: 401,
        json: async () => ({ message: `Invalid access token ${TOKEN}`, internal: 'detalle-interno-del-proveedor' }),
      })),
    );

    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });

    expect(res.status).toBe(502);
    expect(res.body.error).toEqual({ code: 'PROVIDER_ERROR', message: 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.' });
    expect(JSON.stringify(res.body)).not.toContain(TOKEN);
    expect(JSON.stringify(res.body)).not.toContain('detalle-interno-del-proveedor');
    expect(textoEmitido()).not.toContain(TOKEN);
    expect(textoEmitido()).not.toContain('detalle-interno-del-proveedor');
    expect(await query('SELECT id FROM payments')).toEqual([]);
  });

  it('test_una_falla_de_red_tampoco_filtra_el_token', async () => {
    setGateway(
      gatewayConFetch(async () => {
        throw new Error(`fallo de red con ${TOKEN}`);
      }),
    );

    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO' });

    expect(res.status).toBe(502);
    expect(JSON.stringify(res.body)).not.toContain(TOKEN);
    expect(textoEmitido()).not.toContain(TOKEN);
  });

  it('test_el_adaptador_solo_envia_importe_titulo_y_referencia_nunca_datos_de_tarjeta', async () => {
    const enviados = [];
    setGateway(
      gatewayConFetch(async (url, opciones) => {
        enviados.push(opciones.body ?? '');
        return { ok: true, status: 200, json: async () => ({ sandbox_init_point: 'https://sandbox.mp.simulado/pay/abc', results: [] }) };
      }),
    );

    await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'MERCADO_PAGO', reference: 'Folio 1' });

    const cuerpo = JSON.parse(enviados[0]);
    expect(Object.keys(cuerpo).sort()).toEqual(['external_reference', 'items']);
    expect(Object.keys(cuerpo.items[0]).sort()).toEqual(['currency_id', 'quantity', 'title', 'unit_price']);
    expect(enviados[0]).not.toMatch(/card|cvv|token|tarjeta/i);
  });

  it('test_el_token_nunca_se_escribe_en_la_configuracion_ni_en_los_scripts_del_repositorio', async () => {
    const { readFileSync, readdirSync, statSync } = await import('node:fs');
    const { join } = await import('node:path');
    const raiz = join(process.cwd(), '..');
    const revisar = (carpeta) => {
      for (const nombre of readdirSync(carpeta)) {
        if (['node_modules', '.git', 'build', '.dart_tool', 'coverage'].includes(nombre)) continue;
        const ruta = join(carpeta, nombre);
        if (statSync(ruta).isDirectory()) revisar(ruta);
        else if (/\.(js|mjs|json|sql|md|yaml|yml|example|dart|ps1)$/.test(nombre) && !ruta.includes('security.test.js') && !ruta.includes('mercadoPagoAdapter.test.js')) {
          const texto = readFileSync(ruta, 'utf8');
          expect([ruta, /APP_USR-[0-9]{6,}/.test(texto)]).toEqual([ruta, false]);
          expect([ruta, /MERCADOPAGO_ACCESS_TOKEN=\S+/.test(texto)]).toEqual([ruta, false]);
        }
      }
    };
    revisar(join(raiz, 'server'));
    revisar(join(raiz, 'database'));
    revisar(join(raiz, 'client', 'lib'));
    expect(readFileSync(join(raiz, '.env.example'), 'utf8')).toMatch(/^MERCADOPAGO_ACCESS_TOKEN=\s*$/m);
  });

  it('test_las_referencias_con_numero_de_tarjeta_no_se_guardan_nunca', async () => {
    setGateway(proveedorFeliz());

    const res = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'TARJETA', reference: '4111 1111 1111 1111' });

    expect(res.status).toBe(400);
    expect(JSON.stringify(await query('SELECT * FROM payments'))).not.toContain('4111');
  });
});
