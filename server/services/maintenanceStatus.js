import { AppError } from '../utils/AppError.js';
import { MAX_MILEAGE } from './mileageRule.js';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Convierte una fecha (Date o 'YYYY-MM-DD') a número de días desde el origen, ignorando la hora. */
function toDayNumber(value) {
  if (value instanceof Date) return Math.floor(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()) / DAY_MS);
  const [year, month, day] = String(value).slice(0, 10).split('-').map(Number);
  return Math.floor(Date.UTC(year, month - 1, day) / DAY_MS);
}

/**
 * Indicador de un mantenimiento pendiente (función pura; research D-02).
 * - VENCIDO: la fecha objetivo ya pasó o el kilometraje actual alcanzó el objetivo (basta una).
 * - PROXIMO: no vencido y falta `warnDays` días o menos, o `warnKm` km o menos (la fecha de hoy es Próximo).
 * - NORMAL: en cualquier otro caso.
 * Solo se evalúan las condiciones definidas; sin kilometraje actual se omite la de kilometraje.
 */
export function computeIndicator({ dueDate, dueMileage, currentMileage, today, warnDays = 30, warnKm = 1000 }) {
  const hasDate = dueDate !== null && dueDate !== undefined;
  const hasMileage = dueMileage !== null && dueMileage !== undefined && currentMileage !== null && currentMileage !== undefined;

  const daysLeft = hasDate ? toDayNumber(dueDate) - toDayNumber(today) : null;
  const kmLeft = hasMileage ? dueMileage - currentMileage : null;

  if ((hasDate && daysLeft < 0) || (hasMileage && kmLeft <= 0)) return 'VENCIDO';
  if ((hasDate && daysLeft <= warnDays) || (hasMileage && kmLeft <= warnKm)) return 'PROXIMO';
  return 'NORMAL';
}

/**
 * Validación al programar un mantenimiento (RN-11): al menos fecha o kilometraje; la fecha no puede
 * ser anterior a hoy y el kilometraje objetivo debe superar el actual del vehículo.
 */
export function assertMaintenanceTarget({ dueDate, dueMileage, currentMileage, today }) {
  const hasDate = dueDate !== null && dueDate !== undefined;
  const hasMileage = dueMileage !== null && dueMileage !== undefined;

  if (!hasDate && !hasMileage) {
    throw AppError.unprocessable(
      'MAINTENANCE_TARGET_REQUIRED',
      'Indica una fecha, un kilometraje o ambos para el próximo mantenimiento.',
    );
  }
  if (hasDate && toDayNumber(dueDate) < toDayNumber(today)) {
    throw AppError.unprocessable('MAINTENANCE_DATE_IN_PAST', 'La fecha del mantenimiento no puede ser anterior a hoy.');
  }
  if (hasMileage) {
    if (!Number.isInteger(dueMileage) || dueMileage < 0 || dueMileage > MAX_MILEAGE) {
      throw AppError.validation('Revisa los campos marcados.', [
        { field: 'dueMileage', message: `El kilometraje debe ser un entero de 0 a ${MAX_MILEAGE.toLocaleString('es-MX')}.` },
      ]);
    }
    if (currentMileage !== null && currentMileage !== undefined && dueMileage <= currentMileage) {
      throw AppError.unprocessable(
        'MAINTENANCE_MILEAGE_TOO_LOW',
        `El kilometraje del mantenimiento debe ser mayor al actual del vehículo (${currentMileage} km).`,
      );
    }
  }
}
