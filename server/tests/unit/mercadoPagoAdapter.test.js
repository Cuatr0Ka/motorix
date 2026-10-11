import { describe, expect, it } from '@jest/globals';
import { getMercadoPagoConfig, getShopConfig } from '../../config/env.js';
import { createMercadoPagoGateway, getGateway, resetGateway, setGateway } from '../../integrations/mercadoPago.js';

const TOKEN = 'TEST-token-secreto-1234567890';
const API = 'https://mp.simulado.local';

/** `fetch` simulado: guarda las llamadas y responde con lo programado. */
function fetchSimulado(respuesta) {
  const llamadas = [];
  const fetchImpl = async (url, opciones) => {
    llamadas.push({ url, opciones });
    const resultado = typeof respuesta === 'function' ? respuesta(url, opciones) : respuesta;
    if (resultado instanceof Error) throw resultado;
    return {
      ok: resultado.ok ?? true,
      status: resultado.status ?? 200,
      json: async () => {
        if (resultado.jsonInvalido) throw new SyntaxError('JSON inválido');
        return resultado.cuerpo;
      },
    };
  };
  return { fetchImpl, llamadas };
}

const intenta = async (promesa) => {
  try {
    await promesa;
    return null;
  } catch (error) {
    return error;
  }
};

describe('adaptador de Mercado Pago: crear el cobro', () => {
  it('test_crea_la_preferencia_con_el_cuerpo_y_la_autorizacion_esperados', async () => {
    const { fetchImpl, llamadas } = fetchSimulado({ cuerpo: { init_point: 'https://real/x', sandbox_init_point: 'https://sandbox/x' } });
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    const resultado = await gateway.createCheckout({ reference: 'motorix-pago-7', amount: '1250.00', title: 'Orden OS-000012' });

    expect(resultado).toEqual({ checkoutUrl: 'https://sandbox/x' });
    expect(llamadas).toHaveLength(1);
    expect(llamadas[0].url).toBe(`${API}/checkout/preferences`);
    expect(llamadas[0].opciones.method).toBe('POST');
    expect(llamadas[0].opciones.headers.Authorization).toBe(`Bearer ${TOKEN}`);
    expect(JSON.parse(llamadas[0].opciones.body)).toEqual({
      items: [{ title: 'Orden OS-000012', quantity: 1, unit_price: 1250, currency_id: 'MXN' }],
      external_reference: 'motorix-pago-7',
    });
  });

  it('test_con_un_token_real_usa_el_enlace_de_produccion', async () => {
    const { fetchImpl } = fetchSimulado({ cuerpo: { init_point: 'https://real/x', sandbox_init_point: 'https://sandbox/x' } });
    const gateway = createMercadoPagoGateway({ accessToken: 'APP_USR-123', apiUrl: API, fetchImpl });

    const resultado = await gateway.createCheckout({ reference: 'r', amount: 10, title: 't' });

    expect(resultado.checkoutUrl).toBe('https://real/x');
  });

  it('test_si_solo_llega_un_enlace_lo_usa', async () => {
    const { fetchImpl } = fetchSimulado({ cuerpo: { init_point: 'https://real/x' } });
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    expect((await gateway.createCheckout({ reference: 'r', amount: 10, title: 't' })).checkoutUrl).toBe('https://real/x');
  });

  it.each([
    ['sin enlace en la respuesta', { cuerpo: {} }],
    ['respuesta HTTP 500', { ok: false, status: 500, cuerpo: { message: 'secreto interno' } }],
    ['respuesta HTTP 401', { ok: false, status: 401, cuerpo: { message: 'invalid token' } }],
    ['JSON inválido', { jsonInvalido: true }],
    ['red caída', new Error('ECONNREFUSED')],
    ['tiempo agotado', Object.assign(new Error('timeout'), { name: 'TimeoutError' })],
  ])('test_traduce_%s_a_un_error_generico_sin_filtrar_datos', async (_nombre, respuesta) => {
    const { fetchImpl } = fetchSimulado(respuesta);
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    const error = await intenta(gateway.createCheckout({ reference: 'r', amount: 10, title: 't' }));

    expect(error.status).toBe(502);
    expect(error.code).toBe('PROVIDER_ERROR');
    expect(error.message).toBe('No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.');
    expect(JSON.stringify(error)).not.toContain(TOKEN);
    expect(JSON.stringify(error)).not.toContain('secreto interno');
    expect(error.message).not.toContain('ECONNREFUSED');
  });
});

describe('adaptador de Mercado Pago: consultar el estado', () => {
  it('test_busca_por_referencia_externa_y_devuelve_id_y_estado', async () => {
    const { fetchImpl, llamadas } = fetchSimulado({
      cuerpo: { results: [{ id: 99, status: 'approved', payer: { email: 'x@y.z' } }, { id: 98, status: 'rejected' }] },
    });
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    const operaciones = await gateway.findPaymentByReference('motorix-pago-7');

    expect(operaciones).toEqual([{ id: '99', status: 'approved' }, { id: '98', status: 'rejected' }]);
    expect(llamadas[0].url).toBe(`${API}/v1/payments/search?external_reference=motorix-pago-7&sort=date_created&criteria=desc`);
    expect(llamadas[0].opciones.method).toBe('GET');
    expect(llamadas[0].opciones.headers.Authorization).toBe(`Bearer ${TOKEN}`);
  });

  it('test_sin_operaciones_devuelve_una_lista_vacia', async () => {
    const { fetchImpl } = fetchSimulado({ cuerpo: { results: [] } });
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    expect(await gateway.findPaymentByReference('x')).toEqual([]);
  });

  it.each([
    ['respuesta sin results', { cuerpo: {} }],
    ['HTTP 502', { ok: false, status: 502, cuerpo: {} }],
    ['red caída', new Error('ENOTFOUND')],
  ])('test_traduce_%s_a_un_error_del_proveedor', async (_nombre, respuesta) => {
    const { fetchImpl } = fetchSimulado(respuesta);
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    const error = await intenta(gateway.findPaymentByReference('x'));

    expect(error.status).toBe(502);
    expect(error.code).toBe('PROVIDER_ERROR');
  });

  it('test_escapa_la_referencia_en_la_url', async () => {
    const { fetchImpl, llamadas } = fetchSimulado({ cuerpo: { results: [] } });
    const gateway = createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl });

    await gateway.findPaymentByReference('a b&c=d');

    expect(llamadas[0].url).toContain('external_reference=a+b%26c%3Dd');
  });
});

describe('adaptador de Mercado Pago: configuración', () => {
  it('test_sin_token_no_esta_configurado_y_no_llama_al_proveedor', async () => {
    const { fetchImpl, llamadas } = fetchSimulado({ cuerpo: {} });
    const gateway = createMercadoPagoGateway({ accessToken: '', apiUrl: API, fetchImpl });

    const error = await intenta(gateway.createCheckout({ reference: 'r', amount: 10, title: 't' }));
    const consulta = await intenta(gateway.findPaymentByReference('r'));

    expect(gateway.isConfigured()).toBe(false);
    expect(error.status).toBe(503);
    expect(error.code).toBe('PROVIDER_NOT_CONFIGURED');
    expect(consulta.code).toBe('PROVIDER_NOT_CONFIGURED');
    expect(llamadas).toHaveLength(0);
  });

  it('test_con_token_esta_configurado', () => {
    expect(createMercadoPagoGateway({ accessToken: TOKEN, apiUrl: API, fetchImpl: async () => ({}) }).isConfigured()).toBe(true);
  });

  it('test_la_configuracion_lee_el_entorno_con_valores_por_defecto', () => {
    expect(getMercadoPagoConfig({})).toEqual({ accessToken: '', apiUrl: 'https://api.mercadopago.com' });
    expect(getMercadoPagoConfig({ MERCADOPAGO_ACCESS_TOKEN: ' TEST-1 ', MERCADOPAGO_API_URL: 'http://localhost:4000/' })).toEqual({
      accessToken: 'TEST-1',
      apiUrl: 'http://localhost:4000',
    });
    expect(getShopConfig({})).toEqual({ name: 'Motorix Taller Mecánico', address: '', phone: '' });
    expect(getShopConfig({ SHOP_NAME: 'Taller Uno', SHOP_ADDRESS: 'Calle 1', SHOP_PHONE: '555' })).toEqual({
      name: 'Taller Uno',
      address: 'Calle 1',
      phone: '555',
    });
  });

  it('test_las_pruebas_pueden_sustituir_y_restablecer_el_adaptador', () => {
    const falso = { isConfigured: () => true };
    setGateway(falso);
    expect(getGateway()).toBe(falso);

    resetGateway();
    expect(getGateway()).not.toBe(falso);
    expect(typeof getGateway().createCheckout).toBe('function');
    resetGateway();
  });
});
