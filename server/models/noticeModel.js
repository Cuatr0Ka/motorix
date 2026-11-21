import { query } from '../config/db.js';

/**
 * Consultas de apoyo de las notificaciones internas y de los clientes por avisar (Sprint 6). Solo leen: los
 * avisos se calculan al consultar y no se guardan. Lo que ya tiene un servicio con su propio cálculo
 * (mantenimientos y stock) se reutiliza desde ese servicio y no se repite aquí.
 */

/** Inicio (medianoche local) del día de `date` y del día siguiente, para comparar fechas con hora. */
function dayBounds(date) {
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
  return { start, end };
}

const toAppointmentRow = (row) => ({
  id: row.id,
  scheduledAt: row.scheduled_at,
  reason: row.reason,
  status: row.status,
  client: { id: row.client_id, name: row.client_name, phone: row.client_phone },
  vehicle: { id: row.vehicle_id, brand: row.brand, model: row.model, licensePlate: row.license_plate },
});

/**
 * Citas del día indicado que siguen vigentes (estado PENDIENTE o CONFIRMADA), por hora. Las canceladas, las
 * completadas y las que ya están en proceso no generan aviso.
 */
export async function listAppointmentsOn(date, connection) {
  const { start, end } = dayBounds(date);
  const rows = await query(
    `SELECT a.id, a.scheduled_at, a.reason, a.status,
            c.id AS client_id, c.name AS client_name, c.phone AS client_phone,
            v.id AS vehicle_id, v.brand, v.model, v.license_plate
       FROM appointments a
       JOIN clients c ON c.id = a.client_id
       JOIN vehicles v ON v.id = a.vehicle_id
      WHERE a.scheduled_at >= ? AND a.scheduled_at < ?
        AND a.status IN ('PENDIENTE', 'CONFIRMADA')
      ORDER BY a.scheduled_at ASC, a.id ASC`,
    [start, end],
    connection,
  );
  return rows.map(toAppointmentRow);
}
