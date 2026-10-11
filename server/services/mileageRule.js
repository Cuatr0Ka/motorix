import { AppError } from '../utils/AppError.js';

export const MAX_MILEAGE = 2000000;
export const MIN_CORRECTION_REASON = 5;

/**
 * Regla de kilometraje de entrada (RN-3, RN-4). Función pura.
 * - El kilometraje de entrada no puede ser menor al actual del vehículo salvo corrección explícita
 *   con motivo (mínimo 5 caracteres).
 * - Si el vehículo no tiene kilometraje previo, se acepta cualquier valor entre 0 y 2 000 000.
 * Devuelve `{ correctionApplied, reason }`; lanza `MILEAGE_DECREASE` (422) o un error de validación.
 */
export function assertEntryMileage({ previous, entry, correction = false, reason = null }) {
  if (!Number.isInteger(entry) || entry < 0 || entry > MAX_MILEAGE) {
    throw AppError.validation('Revisa los campos marcados.', [
      { field: 'entryMileage', message: `El kilometraje debe ser un entero de 0 a ${MAX_MILEAGE.toLocaleString('es-MX')}.` },
    ]);
  }

  const decreases = previous !== null && previous !== undefined && entry < previous;
  if (!decreases) return { correctionApplied: false, reason: null };

  if (!correction) {
    throw AppError.unprocessable(
      'MILEAGE_DECREASE',
      `El kilometraje de entrada (${entry} km) es menor al registrado del vehículo (${previous} km). ` +
        'Si es una corrección, confírmala de forma explícita e indica el motivo.',
    );
  }

  const text = typeof reason === 'string' ? reason.trim() : '';
  if (text.length < MIN_CORRECTION_REASON) {
    throw AppError.validation('Revisa los campos marcados.', [
      {
        field: 'mileageCorrectionReason',
        message: `El motivo de la corrección debe tener al menos ${MIN_CORRECTION_REASON} caracteres.`,
      },
    ]);
  }
  return { correctionApplied: true, reason: text };
}

/**
 * Regla del kilometraje del servicio (Sprint 3): entero de 0 a 2 000 000 y no menor al de entrada
 * de la orden. Función pura; devuelve el valor validado.
 */
export function assertServiceMileage({ entry, service }) {
  if (!Number.isInteger(service) || service < 0 || service > MAX_MILEAGE) {
    throw AppError.validation('Revisa los campos marcados.', [
      { field: 'serviceMileage', message: `El kilometraje debe ser un entero de 0 a ${MAX_MILEAGE.toLocaleString('es-MX')}.` },
    ]);
  }
  if (service < entry) {
    throw AppError.unprocessable(
      'SERVICE_MILEAGE_TOO_LOW',
      `El kilometraje del servicio (${service} km) no puede ser menor al de entrada (${entry} km).`,
    );
  }
  return service;
}
