import { AppError } from '../utils/AppError.js';

/** Tope de un precio y del total de una orden: 9 999 999.99, en centavos (FR-002, FR-022). */
export const MAX_AMOUNT_CENTS = 999999999;

const invalid = (field, message) => AppError.validation('Revisa los campos marcados.', [{ field, message }]);

/**
 * Importe de una línea de refacción en centavos enteros: cantidad entera por precio unitario en centavos. Como
 * ambos son enteros, el resultado siempre tiene dos decimales exactos y no hay redondeo (FR-005).
 */
export function lineAmountCents(quantity, unitPriceCents) {
  if (typeof quantity !== 'number' || !Number.isInteger(quantity) || quantity <= 0) {
    throw invalid('quantity', 'La cantidad debe ser un número entero mayor a cero.');
  }
  if (typeof unitPriceCents !== 'number' || !Number.isInteger(unitPriceCents) || unitPriceCents < 0) {
    throw invalid('unitPrice', 'El precio debe ser un importe en centavos enteros, sin negativos.');
  }
  return quantity * unitPriceCents;
}

/**
 * Una línea con precio 0 es anterior a los precios de refacciones (Sprint 5). Una línea nueva siempre guarda un
 * precio de venta mayor a cero, así que el cero la identifica sin ambigüedad.
 */
export function isLegacyLine(unitPriceCents) {
  return unitPriceCents === 0;
}

const toCents = (amount) => Math.round(Number(amount) * 100);
const fromCents = (cents) => (cents / 100).toFixed(2);

/**
 * Línea de refacción según el rol de quien consulta (FR-013, FR-014). Administración y recepción reciben el precio
 * unitario, el importe y si la línea es anterior a los precios; el mecánico solo código, nombre, unidad y cantidad.
 */
export function presentOrderPart(line, role) {
  if (!line) return line;
  if (role === 'MECHANIC') {
    const { id, partId, code, name, unit, quantity } = line;
    return { id, partId, code, name, unit, quantity };
  }
  return line;
}

/**
 * Totales de la orden según el rol. Administración y recepción reciben servicios, mano de obra, refacciones y
 * total. El mecánico recibe servicios, mano de obra y un total que suma solo esos dos conceptos, sin las
 * refacciones, para no revelar sus precios (research D-10).
 */
export function presentTotals(totals, role) {
  if (role !== 'MECHANIC') return totals;
  const servicesCents = toCents(totals.services);
  const laborCents = toCents(totals.labor);
  return { services: totals.services, labor: totals.labor, total: fromCents(servicesCents + laborCents) };
}

/** El total de la orden no puede pasar de 9 999 999.99: así el pago de la orden siempre cabe en su tope. */
export function assertTotalWithinLimit(totalCents) {
  if (totalCents > MAX_AMOUNT_CENTS) {
    throw AppError.unprocessable(
      'ORDER_TOTAL_LIMIT',
      'El total de la orden no puede pasar de 9 999 999.99. Reduce la cantidad.',
      { limit: '9999999.99' },
    );
  }
}
