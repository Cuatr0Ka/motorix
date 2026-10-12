import { query } from '../config/db.js';
import { formatFolio } from '../utils/orderFolio.js';

// Consultas de conteo y de actividad reciente del panel de control. No hay tablas de estadísticas: todo se calcula
// al consultar con los datos reales de órdenes, citas, pagos e inventario (FR-018).

const count = async (sql, params = []) => Number((await query(sql, params))[0].total);

/** Órdenes cuyo estado está en la lista (valores de una lista blanca, nunca texto del exterior). */
export function countOrdersByStatuses(statuses) {
  return count(`SELECT COUNT(*) AS total FROM service_orders WHERE status IN (${statuses.map(() => '?').join(', ')})`, statuses);
}

/** Vehículos distintos con una orden Entregada cuya entrega ocurrió en los últimos `days` días. */
export function countAttendedVehicles(days) {
  return count(
    "SELECT COUNT(DISTINCT vehicle_id) AS total FROM service_orders WHERE status = 'ENTREGADO' AND delivered_at >= DATE_SUB(NOW(), INTERVAL ? DAY)",
    [days],
  );
}

/** Citas Pendientes o Confirmadas desde ahora hasta dentro de `days` días. */
export function countUpcomingAppointments(days) {
  return count(
    `SELECT COUNT(*) AS total FROM appointments
      WHERE status IN ('PENDIENTE','CONFIRMADA') AND scheduled_at >= NOW() AND scheduled_at < DATE_ADD(NOW(), INTERVAL ? DAY)`,
    [days],
  );
}

/** Órdenes Terminadas que todavía no tienen un pago Pagado. */
export function countFinishedWithoutPayment() {
  return count(
    `SELECT COUNT(*) AS total FROM service_orders o
      WHERE o.status = 'TERMINADO'
        AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id AND p.status = 'PAGADO')`,
  );
}

export function countPaymentsByStatus(status) {
  return count('SELECT COUNT(*) AS total FROM payments WHERE status = ?', [status]);
}

/** Últimos cambios de estado de las órdenes. `limit` es un entero fijo del servicio. */
export async function recentOrderChanges(limit) {
  const rows = await query(
    `SELECT h.order_id, h.to_status, h.changed_at, u.name AS user_name
       FROM order_status_history h JOIN users u ON u.id = h.changed_by
      ORDER BY h.changed_at DESC, h.id DESC LIMIT ${Math.trunc(limit)}`,
  );
  return rows.map((row) => ({
    orderId: row.order_id,
    folio: formatFolio(row.order_id),
    toStatus: row.to_status,
    changedBy: row.user_name,
    changedAt: row.changed_at,
  }));
}

export async function recentPayments(limit) {
  const rows = await query(
    `SELECT id, order_id, amount, method, status, created_at FROM payments ORDER BY id DESC LIMIT ${Math.trunc(limit)}`,
  );
  return rows.map((row) => ({
    id: row.id,
    orderFolio: formatFolio(row.order_id),
    amount: Number(row.amount).toFixed(2),
    method: row.method,
    status: row.status,
    createdAt: row.created_at,
  }));
}

export async function recentInventoryMovements(limit) {
  const rows = await query(
    `SELECT m.id, p.code, m.type, m.quantity, m.created_at
       FROM inventory_movements m JOIN parts p ON p.id = m.part_id
      ORDER BY m.id DESC LIMIT ${Math.trunc(limit)}`,
  );
  return rows.map((row) => ({
    id: Number(row.id),
    partCode: row.code,
    type: row.type,
    quantity: row.quantity,
    createdAt: row.created_at,
  }));
}

/** Órdenes agrupadas por estado (solo los estados con al menos una orden). */
export async function ordersGroupedByStatus() {
  const rows = await query('SELECT status, COUNT(*) AS total FROM service_orders GROUP BY status');
  return rows.map((row) => ({ status: row.status, total: Number(row.total) }));
}

/** Suma de pagos Pagados por mes (`YYYY-MM`) desde el primer día del mes de hace `months - 1` meses. */
export async function paidIncomeByMonth(months) {
  const rows = await query(
    `SELECT DATE_FORMAT(paid_at, '%Y-%m') AS month, SUM(amount) AS total
       FROM payments
      WHERE status = 'PAGADO' AND paid_at >= DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? MONTH), '%Y-%m-01')
      GROUP BY month`,
    [Math.trunc(months) - 1],
  );
  return rows.map((row) => ({ month: row.month, total: Number(row.total) }));
}

/** Suma de pagos Pagados por método en el mismo periodo que `paidIncomeByMonth`. */
export async function paidIncomeByMethod(months) {
  const rows = await query(
    `SELECT method, SUM(amount) AS total
       FROM payments
      WHERE status = 'PAGADO' AND paid_at >= DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? MONTH), '%Y-%m-01')
      GROUP BY method`,
    [Math.trunc(months) - 1],
  );
  return rows.map((row) => ({ method: row.method, total: Number(row.total) }));
}
