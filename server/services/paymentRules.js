import { AppError } from '../utils/AppError.js';

export const PAYMENT_METHODS = Object.freeze(['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO']);
export const PAYMENT_STATUSES = Object.freeze(['PENDIENTE', 'PAGADO', 'RECHAZADO', 'CANCELADO']);
export const PAYABLE_ORDER_STATUSES = Object.freeze(['TERMINADO', 'ENTREGADO']);
export const MAX_REFERENCE_LENGTH = 100;

// Un pago solo sale de PENDIENTE (y solo los de Mercado Pago llegan a estar pendientes); el resto son estados finales.
const TRANSITIONS = {
  PENDIENTE: ['PAGADO', 'RECHAZADO', 'CANCELADO'],
  PAGADO: [],
  RECHAZADO: [],
  CANCELADO: [],
};

/** Estado con el que nace un pago: efectivo, tarjeta y transferencia ya están cobrados; Mercado Pago espera al proveedor. */
export function initialStatusFor(method) {
  if (!PAYMENT_METHODS.includes(method)) {
    throw AppError.validation('Revisa los campos marcados.', [{ field: 'method', message: 'El método de pago no es válido.' }]);
  }
  return method === 'MERCADO_PAGO' ? 'PENDIENTE' : 'PAGADO';
}

/** Valida un cambio de estado de un pago. Cancelar un pago que no está pendiente tiene su propio error. */
export function assertTransition(from, to) {
  if (!TRANSITIONS[from]?.includes(to)) {
    if (to === 'CANCELADO') {
      throw AppError.conflict('PAYMENT_NOT_CANCELLABLE', 'Solo se puede cancelar un pago que esté Pendiente.');
    }
    throw AppError.conflict('PAYMENT_NOT_PENDING', 'El pago ya no está Pendiente: su estado no puede cambiar.');
  }
}

/** La orden debe estar Terminada o Entregada y tener algo que cobrar (total en centavos o cadena decimal mayor a cero). */
export function assertOrderPayable({ status, totalCents }) {
  if (!PAYABLE_ORDER_STATUSES.includes(status)) {
    throw AppError.conflict('ORDER_NOT_PAYABLE', 'Solo se puede cobrar una orden Terminada o Entregada.');
  }
  if (!Number.isInteger(totalCents) || totalCents <= 0) {
    throw AppError.unprocessable('NOTHING_TO_CHARGE', 'La orden no tiene servicios ni mano de obra: no hay nada que cobrar.');
  }
}

/** El importe enviado (si viene) debe ser igual al total vigente. Ambos en centavos. */
export function assertAmountMatches({ amountCents, totalCents }) {
  if (amountCents !== undefined && amountCents !== null && amountCents !== totalCents) {
    throw AppError.unprocessable(
      'AMOUNT_MISMATCH',
      `El importe no coincide con el total vigente de la orden (${formatCents(totalCents)}).`,
      { total: formatCents(totalCents) },
    );
  }
}

/** Referencia opcional capturada: hasta 100 caracteres y sin parecer un número de tarjeta (RN-14). */
export function assertSafeReference(text) {
  if (text === undefined || text === null || text === '') return;
  const invalid = (message) => AppError.validation('Revisa los campos marcados.', [{ field: 'reference', message }]);
  if (typeof text !== 'string') throw invalid('La referencia no es válida.');
  if (text.length > MAX_REFERENCE_LENGTH) throw invalid(`La referencia no puede pasar de ${MAX_REFERENCE_LENGTH} caracteres.`);
  if (looksLikeCardNumber(text)) {
    throw invalid('La referencia parece un número de tarjeta. No captures números de tarjeta: escribe solo el folio de la operación.');
  }
}

/** Algoritmo de Luhn: lo cumplen los números de tarjeta reales y solo una de cada diez cifras al azar. */
function passesLuhn(digits) {
  let sum = 0;
  let doubleIt = false;
  for (let i = digits.length - 1; i >= 0; i -= 1) {
    let digit = Number(digits[i]);
    if (doubleIt) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleIt = !doubleIt;
  }
  return sum % 10 === 0;
}

/**
 * Detecta un posible número de tarjeta (RN-14): una cifra de 13 a 19 dígitos (con o sin espacios o guiones, que no
 * forme parte de una cifra más larga) que cumple el algoritmo de Luhn. Así se bloquean los números de tarjeta sin
 * rechazar claves de rastreo o folios que solo contienen muchos dígitos.
 */
export function looksLikeCardNumber(text) {
  const candidates = String(text).match(/(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)/g) ?? [];
  return candidates.some((candidate) => passesLuhn(candidate.replace(/\D/g, '')));
}

/**
 * Estado del pago según las operaciones que reporta Mercado Pago (cada una con su `status`). Gana la
 * aprobada; si no hay, la más reciente (la primera de la lista, ya ordenada de la más nueva a la más antigua).
 * Sin operaciones, el pago sigue pendiente.
 */
export function mapProviderStatus(operations) {
  if (!Array.isArray(operations) || operations.length === 0) return { status: 'PENDIENTE', operation: null };
  const approved = operations.find((operation) => operation?.status === 'approved');
  if (approved) return { status: 'PAGADO', operation: approved };
  const latest = operations[0];
  if (latest?.status === 'rejected' || latest?.status === 'cancelled') return { status: 'RECHAZADO', operation: latest };
  return { status: 'PENDIENTE', operation: latest ?? null };
}

/** Centavos enteros → cadena decimal con dos decimales. */
export function formatCents(cents) {
  return (cents / 100).toFixed(2);
}

/** Importe (número o cadena decimal) → centavos enteros. */
export function toCents(amount) {
  return Math.round(Number(amount) * 100);
}
