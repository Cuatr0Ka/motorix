import { getMaintenanceConfig } from '../config/env.js';
import { computeIndicator } from './maintenanceStatus.js';

/** Formato `YYYY-MM-DD` de una fecha de la base (columna DATE), sin desfase de zona horaria. */
export function toDateOnly(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string') return value.slice(0, 10);
  const pad = (n) => String(n).padStart(2, '0');
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
}

/** Mantenimiento listo para la API: fechas en texto e indicador calculado (null si ya fue atendido). */
export function presentMaintenance(row, currentMileage, today = new Date()) {
  const { warnDays, warnKm } = getMaintenanceConfig();
  const dueDate = toDateOnly(row.dueDate);
  return {
    id: row.id,
    description: row.description,
    dueDate,
    dueMileage: row.dueMileage,
    status: row.status,
    indicator:
      row.status === 'PENDIENTE'
        ? computeIndicator({ dueDate, dueMileage: row.dueMileage, currentMileage, today, warnDays, warnKm })
        : null,
    attendedAt: row.attendedAt ?? null,
  };
}

/**
 * Mantenimiento completo (con orden de origen, vehículo y cliente). El mecánico no recibe los datos
 * de contacto del cliente.
 */
export function presentFullMaintenance(maintenance, actor, today = new Date()) {
  const base = presentMaintenance(maintenance, maintenance.vehicle.currentMileage, today);
  const full = {
    ...base,
    orderId: maintenance.orderId,
    orderFolio: maintenance.orderFolio,
    vehicle: maintenance.vehicle,
  };
  if (actor.role !== 'MECHANIC') full.client = maintenance.client;
  return full;
}
