import { AppError } from '../utils/AppError.js';

export const MAX_MOVEMENT_QUANTITY = 100000;
export const MAX_COUNTED_QUANTITY = 1000000;

/** Cantidad de un movimiento o de una línea de orden: entero positivo de hasta 100 000. */
export function assertPositiveInteger(value, field = 'quantity') {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0 || value > MAX_MOVEMENT_QUANTITY) {
    throw AppError.validation('Revisa los campos marcados.', [
      { field, message: `La cantidad debe ser un número entero entre 1 y ${MAX_MOVEMENT_QUANTITY.toLocaleString('es-MX')}.` },
    ]);
  }
  return value;
}

/**
 * Diferencia de un ajuste por conteo físico: contado − stock actual (research D-08).
 * La cantidad contada debe ser un entero ≥ 0; una diferencia de cero se rechaza.
 */
export function computeAdjustmentDelta({ stock, countedQuantity }) {
  if (
    typeof countedQuantity !== 'number' ||
    !Number.isInteger(countedQuantity) ||
    countedQuantity < 0 ||
    countedQuantity > MAX_COUNTED_QUANTITY
  ) {
    throw AppError.validation('Revisa los campos marcados.', [
      { field: 'countedQuantity', message: `La cantidad contada debe ser un entero de 0 a ${MAX_COUNTED_QUANTITY.toLocaleString('es-MX')}.` },
    ]);
  }
  const delta = countedQuantity - stock;
  if (delta === 0) {
    throw AppError.unprocessable('NO_ADJUSTMENT_DIFFERENCE', 'La cantidad contada es igual al stock actual: no hay nada que ajustar.');
  }
  return delta;
}

/** Cantidad con signo de un movimiento: entrada (+) o salida (−). Los ajustes ya traen su signo. */
export function signedQuantity(type, magnitude) {
  if (type === 'IN') return Math.abs(magnitude);
  if (type === 'OUT') return -Math.abs(magnitude);
  return magnitude;
}

/** Rechaza una salida que dejaría el stock negativo (RN-8). */
export function assertStockAvailable({ available, requested }) {
  if (requested > available) {
    throw AppError.conflict(
      'INSUFFICIENT_STOCK',
      `No hay stock suficiente: solo hay ${available} disponibles y se solicitaron ${requested}.`,
      { available, requested },
    );
  }
}
