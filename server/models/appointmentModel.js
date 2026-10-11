import { query } from '../config/db.js';
import { formatFolio } from '../utils/orderFolio.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const SELECT = `SELECT a.id, a.status, a.scheduled_at, a.reason, a.notes, a.cancel_reason, a.cancelled_at,
       c.id AS client_id, c.name AS client_name, c.phone AS client_phone,
       v.id AS vehicle_id, v.brand, v.model, v.year, v.license_plate,
       o.id AS order_id, o.status AS order_status
  FROM appointments a
  JOIN clients c ON c.id = a.client_id
  JOIN vehicles v ON v.id = a.vehicle_id
  LEFT JOIN service_orders o ON o.appointment_id = a.id`;

const toAppointment = (row) => ({
  id: row.id,
  status: row.status,
  scheduledAt: row.scheduled_at,
  reason: row.reason,
  notes: row.notes,
  cancelReason: row.cancel_reason,
  cancelledAt: row.cancelled_at,
  client: { id: row.client_id, name: row.client_name, phone: row.client_phone },
  vehicle: { id: row.vehicle_id, brand: row.brand, model: row.model, year: row.year, licensePlate: row.license_plate },
  order: row.order_id ? { id: row.order_id, folio: formatFolio(row.order_id), status: row.order_status } : null,
});

/** Listado paginado por fecha ascendente, con filtros de estado y fechas y búsqueda por cliente o placa. */
export async function list({ search, status, from, to, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    conditions.push('(c.name LIKE ? OR v.license_plate LIKE ?)');
    params.push(pattern, pattern);
  }
  if (status) {
    conditions.push('a.status = ?');
    params.push(status);
  }
  if (from) {
    conditions.push('a.scheduled_at >= ?');
    params.push(from);
  }
  if (to) {
    conditions.push('a.scheduled_at <= ?');
    params.push(to);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `${SELECT} ${where} ORDER BY a.scheduled_at ASC, a.id ASC LIMIT ${limit} OFFSET ${offset}`,
    params,
  );
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM appointments a
       JOIN clients c ON c.id = a.client_id
       JOIN vehicles v ON v.id = a.vehicle_id ${where}`,
    params,
  );
  return { items: rows.map(toAppointment), total: Number(total) };
}

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE a.id = ?`, [id], connection);
  return rows[0] ? toAppointment(rows[0]) : null;
}

/** Cita activa del mismo vehículo en ese horario (distinta de `excludeId`), si existe. */
export async function findActiveSlot(vehicleId, scheduledAt, excludeId = 0) {
  const rows = await query(
    `SELECT id FROM appointments
      WHERE vehicle_id = ? AND scheduled_at = ? AND status NOT IN ('CANCELADA','COMPLETADA') AND id <> ? LIMIT 1`,
    [vehicleId, scheduledAt, excludeId],
  );
  return rows[0] ?? null;
}

export async function create({ clientId, vehicleId, scheduledAt, reason, notes, createdBy }) {
  const result = await query(
    `INSERT INTO appointments (client_id, vehicle_id, scheduled_at, reason, notes, created_by)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [clientId, vehicleId, scheduledAt, reason, notes ?? null, createdBy],
  );
  return result.insertId;
}

// Columnas editables (lista blanca: nunca se arma SQL con nombres recibidos del exterior).
const EDITABLE_COLUMNS = { scheduledAt: 'scheduled_at', reason: 'reason', notes: 'notes' };

/** Actualiza solo los campos presentes. Devuelve true si se envió algún cambio. */
export async function update(id, fields) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE_COLUMNS)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      params.push(fields[key]);
    }
  }
  if (assignments.length === 0) return false;
  await query(`UPDATE appointments SET ${assignments.join(', ')} WHERE id = ?`, [...params, id]);
  return true;
}

/**
 * Cambia el estado solo si la cita sigue en alguno de los estados `fromStatuses` (evita carreras).
 * Devuelve true si se aplicó el cambio.
 */
export async function setStatusIf(id, fromStatuses, toStatus, extra = {}, connection) {
  const sets = ['status = ?'];
  const params = [toStatus];
  if (extra.cancelReason !== undefined) {
    sets.push('cancel_reason = ?');
    params.push(extra.cancelReason);
  }
  if (extra.cancelledAt !== undefined) {
    sets.push('cancelled_at = ?');
    params.push(extra.cancelledAt);
  }
  const placeholders = fromStatuses.map(() => '?').join(', ');
  const result = await query(
    `UPDATE appointments SET ${sets.join(', ')} WHERE id = ? AND status IN (${placeholders})`,
    [...params, id, ...fromStatuses],
    connection,
  );
  return result.affectedRows > 0;
}

/** Bloquea la cita dentro de una transacción (para crear su orden sin carreras). */
export async function lockById(id, connection) {
  const rows = await query(
    'SELECT id, status, vehicle_id, reason FROM appointments WHERE id = ? FOR UPDATE',
    [id],
    connection,
  );
  return rows[0] ?? null;
}
