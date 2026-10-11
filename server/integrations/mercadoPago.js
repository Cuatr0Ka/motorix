import { getMercadoPagoConfig } from '../config/env.js';
import { AppError } from '../utils/AppError.js';

const TIMEOUT_MS = 15000;

const providerError = () => new AppError(502, 'PROVIDER_ERROR', 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.');
const notConfigured = () =>
  new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'Mercado Pago no está configurado en este entorno.');

/**
 * Adaptador de Mercado Pago (Checkout Pro, modo de pruebas). Es el ÚNICO módulo que habla con el proveedor.
 * - Usa el `fetch` de Node.js (sin SDK); `fetchImpl` permite sustituirlo en pruebas.
 * - El token solo se envía en el encabezado de la petición: nunca se registra ni se devuelve.
 * - Cualquier fallo del proveedor se traduce a un error genérico en español, sin reenviar su respuesta.
 * - No envía ni recibe datos de tarjeta: el cliente paga en la página de Mercado Pago.
 */
export function createMercadoPagoGateway({ accessToken, apiUrl, fetchImpl = globalThis.fetch }) {
  const isConfigured = () => Boolean(accessToken);

  async function request(method, path, body) {
    if (!isConfigured()) throw notConfigured();
    let response;
    try {
      response = await fetchImpl(`${apiUrl}${path}`, {
        method,
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', Accept: 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      throw providerError();
    }
    if (!response.ok) throw providerError();
    try {
      return await response.json();
    } catch {
      throw providerError();
    }
  }

  return {
    isConfigured,

    /** Crea una preferencia de cobro por el importe de la orden y devuelve el enlace para que el cliente pague. */
    async createCheckout({ reference, amount, title }) {
      const data = await request('POST', '/checkout/preferences', {
        items: [{ title, quantity: 1, unit_price: Number(amount), currency_id: 'MXN' }],
        external_reference: reference,
      });
      // Con credenciales de pruebas (TEST-…) el enlace de cobro es el del entorno de pruebas.
      const testing = accessToken.startsWith('TEST-');
      const checkoutUrl = (testing ? data?.sandbox_init_point : data?.init_point) ?? data?.init_point ?? data?.sandbox_init_point;
      if (typeof checkoutUrl !== 'string' || checkoutUrl === '') throw providerError();
      return { checkoutUrl };
    },

    /** Operaciones del proveedor para una referencia, de la más reciente a la más antigua. */
    async findPaymentByReference(reference) {
      const query = new URLSearchParams({ external_reference: reference, sort: 'date_created', criteria: 'desc' });
      const data = await request('GET', `/v1/payments/search?${query}`);
      if (!Array.isArray(data?.results)) throw providerError();
      return data.results.map((operation) => ({ id: String(operation.id), status: String(operation.status) }));
    },
  };
}

let gateway;

/** Adaptador vigente: el real (construido desde el entorno una sola vez) o el que haya fijado una prueba. */
export function getGateway() {
  if (!gateway) gateway = createMercadoPagoGateway(getMercadoPagoConfig());
  return gateway;
}

/** Sustituye el adaptador (solo para pruebas). */
export function setGateway(fake) {
  gateway = fake;
}

/** Vuelve a construir el adaptador real desde el entorno en el siguiente uso. */
export function resetGateway() {
  gateway = undefined;
}
