import { query } from '../config/db.js';
import { STALLED_STATUSES } from '../services/noticeRules.js';

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

const toFinishedOrder = (row) => ({
  id: row.id,
  finishedAt: row.finished_at ?? row.updated_at ?? row.created_at,
  client: { id: row.client_id, name: row.client_name, phone: row.client_phone },
  vehicle: { id: row.vehicle_id, brand: row.brand, model: row.model, licensePlate: row.license_plate },
});

/**
 * Órdenes Terminadas que todavía no se entregan (el vehículo está listo), con su cliente y vehículo. La fecha en
 * que quedaron Terminadas es la del último cambio de estado a TERMINADO del historial (o la de actualización).
 */
export async function listFinishedOrders(connection) {
  const rows = await query(
    `SELECT o.id, o.created_at, o.updated_at,
            (SELECT MAX(h.changed_at) FROM order_status_history h WHERE h.order_id = o.id AND h.to_status = 'TERMINADO') AS finished_at,
            c.id AS client_id, c.name AS client_name, c.phone AS client_phone,
            v.id AS vehicle_id, v.brand, v.model, v.license_plate
       FROM service_orders o
       JOIN clients c ON c.id = o.client_id
       JOIN vehicles v ON v.id = o.vehicle_id
      WHERE o.status = 'TERMINADO'
      ORDER BY o.id ASC`,
    [],
    connection,
  );
  return rows.map(toFinishedOrder);
}

/** Orden por identificador (para comprobar el hecho de un aviso al cliente), o null si no existe. */
export async function findOrderFact(id, connection) {
  const rows = await query('SELECT id, status, client_id FROM service_orders WHERE id = ?', [id], connection);
  return rows[0] ? { id: rows[0].id, status: rows[0].status, clientId: rows[0].client_id } : null;
}

/** Cita por identificador (para comprobar el hecho de un aviso al cliente), o null si no existe. */
export async function findAppointmentFact(id, connection) {
  const rows = await query(
    'SELECT id, status, scheduled_at, client_id FROM appointments WHERE id = ?',
    [id],
    connection,
  );
  return rows[0]
    ? { id: rows[0].id, status: rows[0].status, scheduledAt: rows[0].scheduled_at, clientId: rows[0].client_id }
    : null;
}

const toOpenOrder = (row) => ({
  id: row.id,
  status: row.status,
  mechanicId: row.mechanic_id,
  createdAt: row.created_at,
  lastChangeAt: row.last_changed_at ?? null,
  lastHistoryId: row.last_history_id ?? 0,
  client: { id: row.client_id, name: row.client_name },
  vehicle: { id: row.vehicle_id, brand: row.brand, model: row.model, licensePlate: row.license_plate },
});

/**
 * Órdenes abiertas (Recibida, Diagnóstico, En reparación o Esperando refacción) con la fecha y el identificador de
 * su último cambio de estado, tomados del historial (el cambio más reciente). Sin historial, queda en null y el
 * servicio usa la fecha de creación. Con `mechanicId` solo trae las órdenes asignadas a esa persona.
 */
export async function listOpenOrdersWithLastChange({ mechanicId } = {}, connection) {
  const placeholders = STALLED_STATUSES.map(() => '?').join(', ');
  const params = [...STALLED_STATUSES];
  let mechanicFilter = '';
  if (mechanicId !== undefined && mechanicId !== null) {
    mechanicFilter = 'AND o.mechanic_id = ?';
    params.push(mechanicId);
  }
  const rows = await query(
    `SELECT o.id, o.status, o.mechanic_id, o.created_at,
            (SELECT h.changed_at FROM order_status_history h WHERE h.order_id = o.id ORDER BY h.changed_at DESC, h.id DESC LIMIT 1) AS last_changed_at,
            (SELECT h.id FROM order_status_history h WHERE h.order_id = o.id ORDER BY h.changed_at DESC, h.id DESC LIMIT 1) AS last_history_id,
            c.id AS client_id, c.name AS client_name,
            v.id AS vehicle_id, v.brand, v.model, v.license_plate
       FROM service_orders o
       JOIN clients c ON c.id = o.client_id
       JOIN vehicles v ON v.id = o.vehicle_id
      WHERE o.status IN (${placeholders}) ${mechanicFilter}
      ORDER BY o.id ASC`,
    params,
    connection,
  );
  return rows.map(toOpenOrder);
}
