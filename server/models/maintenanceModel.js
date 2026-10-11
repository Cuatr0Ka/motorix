import { query } from '../config/db.js';
import { formatFolio } from '../utils/orderFolio.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const SELECT = `SELECT m.id, m.vehicle_id, m.order_id, m.description, m.due_date, m.due_mileage, m.status, m.attended_at,
       o.mechanic_id,
       v.brand, v.model, v.license_plate, v.current_mileage,
       c.id AS client_id, c.name AS client_name, c.phone AS client_phone
  FROM maintenance m
  JOIN vehicles v ON v.id = m.vehicle_id
  JOIN clients c ON c.id = v.client_id
  JOIN service_orders o ON o.id = m.order_id`;

/** Fila → mantenimiento con vehículo, cliente y mecánico de la orden de origen. */
const toMaintenance = (row) => ({
  id: row.id,
  vehicleId: row.vehicle_id,
  orderId: row.order_id,
  orderFolio: formatFolio(row.order_id),
  mechanicId: row.mechanic_id,
  description: row.description,
  dueDate: row.due_date,
  dueMileage: row.due_mileage,
  status: row.status,
  attendedAt: row.attended_at,
  vehicle: {
    id: row.vehicle_id,
    brand: row.brand,
    model: row.model,
    licensePlate: row.license_plate,
    currentMileage: row.current_mileage,
  },
  client: { id: row.client_id, name: row.client_name, phone: row.client_phone },
});

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE m.id = ?`, [id], connection);
  return rows[0] ? toMaintenance(rows[0]) : null;
}

/** Bloquea la fila del mantenimiento dentro de una transacción. */
export async function lockById(id, connection) {
  const rows = await query('SELECT id, status, vehicle_id FROM maintenance WHERE id = ? FOR UPDATE', [id], connection);
  return rows[0] ?? null;
}

/** Último mantenimiento programado desde la orden (con el kilometraje actual del vehículo). */
export async function findLatestByOrder(orderId, connection) {
  const rows = await query(
    `SELECT m.id, m.description, m.due_date, m.due_mileage, m.status, m.attended_at, v.current_mileage
       FROM maintenance m JOIN vehicles v ON v.id = m.vehicle_id
      WHERE m.order_id = ? ORDER BY m.id DESC LIMIT 1`,
    [orderId],
    connection,
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    description: row.description,
    dueDate: row.due_date,
    dueMileage: row.due_mileage,
    status: row.status,
    attendedAt: row.attended_at,
    currentMileage: row.current_mileage,
  };
}

/** Mantenimiento pendiente (vigente) del vehículo, si lo hay. */
export async function findPendingByVehicle(vehicleId, connection) {
  const rows = await query(
    `SELECT id, order_id, description, due_date, due_mileage, status, attended_at
       FROM maintenance WHERE vehicle_id = ? AND status = 'PENDIENTE' LIMIT 1`,
    [vehicleId],
    connection,
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    orderId: row.order_id,
    description: row.description,
    dueDate: row.due_date,
    dueMileage: row.due_mileage,
    status: row.status,
    attendedAt: row.attended_at,
  };
}

export async function insert(data, connection) {
  const result = await query(
    `INSERT INTO maintenance (vehicle_id, order_id, description, due_date, due_mileage, created_by)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [data.vehicleId, data.orderId, data.description, data.dueDate ?? null, data.dueMileage ?? null, data.createdBy],
    connection,
  );
  return result.insertId;
}

/** Pasa a Atendido los pendientes del vehículo (al programar uno nuevo). */
export async function attendPendingByVehicle(vehicleId, connection) {
  await query(
    "UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE vehicle_id = ? AND status = 'PENDIENTE'",
    [vehicleId],
    connection,
  );
}

export async function markAttended(id, connection) {
  await query("UPDATE maintenance SET status = 'ATENDIDO', attended_at = NOW() WHERE id = ?", [id], connection);
}

// Columnas editables (lista blanca).
const EDITABLE = { description: 'description', dueDate: 'due_date', dueMileage: 'due_mileage' };

export async function update(id, fields, connection) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      params.push(fields[key]);
    }
  }
  if (assignments.length === 0) return false;
  await query(`UPDATE maintenance SET ${assignments.join(', ')} WHERE id = ?`, [...params, id], connection);
  return true;
}

/**
 * Lista de mantenimientos con el indicador resuelto en SQL (equivalente a `computeIndicator`) para
 * filtrar, ordenar y paginar: Vencidos, Próximos y Normales; dentro de cada grupo, por fecha objetivo.
 * `today` es una fecha 'YYYY-MM-DD'.
 */
export async function list({ status, indicator, search, page, pageSize, today, warnDays, warnKm }) {
  const overdue = `(
      (m.due_date IS NOT NULL AND m.due_date < ?)
      OR (m.due_mileage IS NOT NULL AND v.current_mileage IS NOT NULL AND v.current_mileage >= m.due_mileage)
    )`;
  const upcoming = `(
      (m.due_date IS NOT NULL AND DATEDIFF(m.due_date, ?) <= ?)
      OR (m.due_mileage IS NOT NULL AND v.current_mileage IS NOT NULL AND m.due_mileage - v.current_mileage <= ?)
    )`;
  const rank = `CASE WHEN m.status <> 'PENDIENTE' THEN 3 WHEN ${overdue} THEN 0 WHEN ${upcoming} THEN 1 ELSE 2 END`;
  const rankParams = [today, today, warnDays, warnKm];

  const conditions = ['m.status = ?'];
  const whereParams = [status];
  if (search) {
    const pattern = likePattern(search);
    conditions.push('(c.name LIKE ? OR v.license_plate LIKE ?)');
    whereParams.push(pattern, pattern);
  }
  if (indicator && status === 'PENDIENTE') {
    conditions.push(`${rank} = ?`);
    whereParams.push(...rankParams, { VENCIDO: 0, PROXIMO: 1, NORMAL: 2 }[indicator]);
  }
  const where = `WHERE ${conditions.join(' AND ')}`;
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `${SELECT} ${where}
      ORDER BY ${rank} ASC, m.due_date IS NULL ASC, m.due_date ASC, m.id ASC
      LIMIT ${limit} OFFSET ${offset}`,
    [...whereParams, ...rankParams],
  );
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM maintenance m
       JOIN vehicles v ON v.id = m.vehicle_id
       JOIN clients c ON c.id = v.client_id ${where}`,
    whereParams,
  );
  return { items: rows.map(toMaintenance), total: Number(total) };
}
