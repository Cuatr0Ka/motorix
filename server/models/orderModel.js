import { query } from '../config/db.js';
import { formatFolio, parseFolioSearch } from '../utils/orderFolio.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const SELECT = `SELECT o.id, o.status, o.reported_problem, o.entry_mileage, o.created_at, o.delivered_at,
       o.diagnosis, o.observations, o.recommendations, o.mileage_correction, o.mileage_correction_reason,
       o.mechanic_id, o.appointment_id, a.status AS appointment_status,
       c.id AS client_id, c.name AS client_name,
       v.id AS vehicle_id, v.brand, v.model, v.license_plate,
       m.name AS mechanic_name
  FROM service_orders o
  JOIN clients c ON c.id = o.client_id
  JOIN vehicles v ON v.id = o.vehicle_id
  LEFT JOIN users m ON m.id = o.mechanic_id
  LEFT JOIN appointments a ON a.id = o.appointment_id`;

/** Fila → orden con todos los campos (el servicio decide cuáles se exponen). */
const toOrder = (row) => ({
  id: row.id,
  folio: formatFolio(row.id),
  status: row.status,
  reportedProblem: row.reported_problem,
  entryMileage: row.entry_mileage,
  createdAt: row.created_at,
  deliveredAt: row.delivered_at,
  diagnosis: row.diagnosis,
  observations: row.observations,
  recommendations: row.recommendations,
  mileageCorrection: Boolean(row.mileage_correction),
  mileageCorrectionReason: row.mileage_correction_reason,
  mechanicId: row.mechanic_id,
  appointment: row.appointment_id ? { id: row.appointment_id, status: row.appointment_status } : null,
  client: { id: row.client_id, name: row.client_name },
  vehicle: { id: row.vehicle_id, brand: row.brand, model: row.model, licensePlate: row.license_plate },
  mechanic: row.mechanic_id ? { id: row.mechanic_id, name: row.mechanic_name } : null,
});

/**
 * Listado paginado (más recientes primero). `excludeStatus` oculta un estado (por ejemplo, las
 * entregadas en la vista del mecánico). La búsqueda acepta folio, nombre del cliente o placa.
 */
export async function list({ search, status, mechanicId, excludeStatus, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    const folioId = parseFolioSearch(search);
    conditions.push(folioId ? '(o.id = ? OR c.name LIKE ? OR v.license_plate LIKE ?)' : '(c.name LIKE ? OR v.license_plate LIKE ?)');
    if (folioId) params.push(folioId);
    params.push(pattern, pattern);
  }
  if (status) {
    conditions.push('o.status = ?');
    params.push(status);
  } else if (excludeStatus) {
    conditions.push('o.status <> ?');
    params.push(excludeStatus);
  }
  if (mechanicId) {
    conditions.push('o.mechanic_id = ?');
    params.push(mechanicId);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(`${SELECT} ${where} ORDER BY o.id DESC LIMIT ${limit} OFFSET ${offset}`, params);
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM service_orders o
       JOIN clients c ON c.id = o.client_id
       JOIN vehicles v ON v.id = o.vehicle_id ${where}`,
    params,
  );
  return { items: rows.map(toOrder), total: Number(total) };
}

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE o.id = ?`, [id], connection);
  return rows[0] ? toOrder(rows[0]) : null;
}

/** Orden no entregada del vehículo, si existe (regla de una sola orden abierta). */
export async function findOpenByVehicle(vehicleId, connection) {
  const rows = await query(
    "SELECT id FROM service_orders WHERE vehicle_id = ? AND status <> 'ENTREGADO' LIMIT 1",
    [vehicleId],
    connection,
  );
  return rows[0] ?? null;
}

/** Orden abierta del vehículo, con folio (para los detalles de `OPEN_ORDER_EXISTS`). */
export async function findOpenOrderRef(vehicleId) {
  const open = await findOpenByVehicle(vehicleId);
  return open ? { orderId: open.id, folio: formatFolio(open.id) } : null;
}

export async function create(data, connection) {
  const result = await query(
    `INSERT INTO service_orders
       (client_id, vehicle_id, appointment_id, mechanic_id, reported_problem, entry_mileage,
        mileage_correction, mileage_correction_reason, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      data.clientId,
      data.vehicleId,
      data.appointmentId ?? null,
      data.mechanicId ?? null,
      data.reportedProblem,
      data.entryMileage,
      data.mileageCorrection ? 1 : 0,
      data.mileageCorrectionReason ?? null,
      data.createdBy,
    ],
    connection,
  );
  return result.insertId;
}

/** Bloquea la fila de la orden dentro de una transacción. */
export async function lockById(id, connection) {
  const rows = await query(
    'SELECT id, status, mechanic_id FROM service_orders WHERE id = ? FOR UPDATE',
    [id],
    connection,
  );
  return rows[0] ?? null;
}

/** Asigna (o quita con null) el mecánico de la orden. */
export async function setMechanic(id, mechanicId, connection) {
  await query('UPDATE service_orders SET mechanic_id = ? WHERE id = ?', [mechanicId, id], connection);
}

// Columnas del trabajo editables (lista blanca: nunca se arma SQL con nombres recibidos del exterior).
const WORK_COLUMNS = { diagnosis: 'diagnosis', observations: 'observations', recommendations: 'recommendations' };

/** Actualiza solo los campos del trabajo presentes. Devuelve true si se envió algún cambio. */
export async function updateWork(id, fields, connection) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(WORK_COLUMNS)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      params.push(fields[key]);
    }
  }
  if (assignments.length === 0) return false;
  await query(`UPDATE service_orders SET ${assignments.join(', ')} WHERE id = ?`, [...params, id], connection);
  return true;
}

/**
 * Cambia el estado solo si la orden sigue en `fromStatus` (comparación atómica: si otra persona la
 * cambió antes, no se actualiza nada). Al entregar fija `delivered_at`. Devuelve true si se aplicó.
 */
export async function updateStatusIf(id, fromStatus, toStatus, connection) {
  const result = await query(
    `UPDATE service_orders
        SET status = ?, delivered_at = IF(? = 'ENTREGADO', NOW(), delivered_at)
      WHERE id = ? AND status = ?`,
    [toStatus, toStatus, id, fromStatus],
    connection,
  );
  return result.affectedRows > 0;
}

/** Estado vigente de la orden (para reportar un conflicto de estado). */
export async function currentStatus(id, connection) {
  const rows = await query('SELECT status FROM service_orders WHERE id = ?', [id], connection);
  return rows[0]?.status ?? null;
}
