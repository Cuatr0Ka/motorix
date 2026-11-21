const pad = (n) => String(n).padStart(2, '0');

/** Fecha local `AAAA-MM-DD` a `days` días de `from` (sin desfases de zona horaria). */
function addDays(from, days) {
  const date = new Date(from.getFullYear(), from.getMonth(), from.getDate() + days);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/**
 * Propuesta del próximo mantenimiento (módulo puro, sin acceso a la base). De los tipos de servicio de la orden con
 * intervalo toma el MÁS CORTO de cada eje: fecha = hoy + días; kilometraje = el del servicio (o el actual del vehículo)
 * + kilómetros. Devuelve `null` si ningún tipo tiene intervalo. Es solo una propuesta que la persona corrige.
 */
export function suggestNextMaintenance({ serviceTypes, today = new Date(), serviceMileage, currentMileage }) {
  const unique = [...new Map(serviceTypes.map((type) => [type.id, type])).values()];
  const withInterval = unique.filter((type) => type.intervalDays != null || type.intervalKm != null);
  if (withInterval.length === 0) return null;

  const days = withInterval.map((type) => type.intervalDays).filter((value) => value != null);
  const km = withInterval.map((type) => type.intervalKm).filter((value) => value != null);
  const baseMileage = serviceMileage ?? currentMileage ?? 0;

  return {
    dueDate: days.length > 0 ? addDays(today, Math.min(...days)) : null,
    dueMileage: km.length > 0 ? baseMileage + Math.min(...km) : null,
    basedOn: withInterval.map((type) => ({ serviceTypeId: type.id, name: type.name })),
  };
}
