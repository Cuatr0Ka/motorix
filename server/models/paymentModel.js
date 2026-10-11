import { query } from '../config/db.js';
import { formatFolio, parseFolioSearch } from '../utils/orderFolio.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const SELECT = `SELECT p.id, p.order_id, p.amount, p.method, p.status, p.reference, p.external_reference,
       p.external_payment_id, p.checkout_url, p.last_checked_at, p.paid_at, p.created_at,
       u.id AS user_id, u.name AS user_name,
       c.id AS client_id, c.name AS client_name,
       v.id AS vehicle_id, v.license_plate
  FROM payments p
  JOIN service_orders o ON o.id = p.order_id
  JOIN clients c ON c.id = o.client_id
  JOIN vehicles v ON v.id = o.vehicle_id
  JOIN users u ON u.id = p.created_by`;

/** Importe de la base ("1250.00") como cadena con dos decimales. */
const money = (value) => Number(value).toFixed(2);

/** Fila → pago de la API. Nunca incluye datos de tarjeta (la tabla no los tiene). */
const toPayment = (row) => ({
  id: row.id,
  orderId: row.order_id,
  orderFolio: formatFolio(row.order_id),
  amount: money(row.amount),
  method: row.method,
  status: row.status,
  reference: row.reference,
  externalReference: row.external_reference,
  externalPaymentId: row.external_payment_id,
  checkoutUrl: row.checkout_url,
  lastCheckedAt: row.last_checked_at,
  paidAt: row.paid_at,
  createdAt: row.created_at,
  createdBy: { id: row.user_id, name: row.user_name },
  client: { id: row.client_id, name: row.client_name },
  vehicle: { id: row.vehicle_id, licensePlate: row.license_plate },
});

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE p.id = ?`, [id], connection);
  return rows[0] ? toPayment(rows[0]) : null;
}

/** Bloquea la fila del pago dentro de una transacción y devuelve su estado vigente. */
export async function lockById(id, connection) {
  const rows = await query('SELECT id, order_id, status, method, amount FROM payments WHERE id = ? FOR UPDATE', [id], connection);
  return rows[0] ?? null;
}

/** Pagos de una orden, del más reciente al más antiguo (todos los estados). */
export async function listByOrder(orderId, connection) {
  const rows = await query(`${SELECT} WHERE p.order_id = ? ORDER BY p.id DESC`, [orderId], connection);
  return rows.map(toPayment);
}

/** Pago vigente (Pendiente o Pagado) de la orden, si existe. */
export async function findActiveByOrder(orderId, connection) {
  const rows = await query(`${SELECT} WHERE p.order_id = ? AND p.status IN ('PENDIENTE','PAGADO') LIMIT 1`, [orderId], connection);
  return rows[0] ? toPayment(rows[0]) : null;
}

/** Listado paginado, más recientes primero. La búsqueda acepta folio de orden, nombre del cliente o placa. */
export async function list({ search, status, method, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    const folioId = parseFolioSearch(search);
    conditions.push(folioId ? '(p.order_id = ? OR c.name LIKE ? OR v.license_plate LIKE ?)' : '(c.name LIKE ? OR v.license_plate LIKE ?)');
    if (folioId) params.push(folioId);
    params.push(pattern, pattern);
  }
  if (status) {
    conditions.push('p.status = ?');
    params.push(status);
  }
  if (method) {
    conditions.push('p.method = ?');
    params.push(method);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(`${SELECT} ${where} ORDER BY p.id DESC LIMIT ${limit} OFFSET ${offset}`, params);
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM payments p
       JOIN service_orders o ON o.id = p.order_id
       JOIN clients c ON c.id = o.client_id
       JOIN vehicles v ON v.id = o.vehicle_id ${where}`,
    params,
  );
  return { items: rows.map(toPayment), total: Number(total) };
}

/** Alta de un pago. Los pagos ya cobrados llevan `paid_at` = ahora. */
export async function insert({ orderId, amount, method, status, reference, createdBy }, connection) {
  const result = await query(
    `INSERT INTO payments (order_id, amount, method, status, reference, paid_at, created_by)
     VALUES (?, ?, ?, ?, ?, ${status === 'PAGADO' ? 'NOW()' : 'NULL'}, ?)`,
    [orderId, amount, method, status, reference ?? null, createdBy],
    connection,
  );
  return result.insertId;
}

/** Guarda la referencia externa y el enlace de cobro de un pago de Mercado Pago. */
export async function setCheckout(id, { externalReference, checkoutUrl }, connection) {
  await query('UPDATE payments SET external_reference = ?, checkout_url = ? WHERE id = ?', [externalReference, checkoutUrl, id], connection);
}

/** Pasa un pago pendiente a Pagado guardando la operación del proveedor. */
export async function markPaid(id, { externalPaymentId }, connection) {
  await query(
    "UPDATE payments SET status = 'PAGADO', paid_at = NOW(), external_payment_id = ?, last_checked_at = NOW() WHERE id = ?",
    [externalPaymentId ?? null, id],
    connection,
  );
}

/** Pasa un pago pendiente a Rechazado o Cancelado (estados finales sin fecha de pago). */
export async function markClosed(id, status, connection) {
  await query('UPDATE payments SET status = ?, last_checked_at = IF(? = \'RECHAZADO\', NOW(), last_checked_at) WHERE id = ?', [status, status, id], connection);
}

/** Registra que se consultó al proveedor (el pago sigue pendiente). */
export async function touchChecked(id, connection) {
  await query('UPDATE payments SET last_checked_at = NOW() WHERE id = ?', [id], connection);
}

/** Identificador del ticket de la orden, si existe (para el bloque de cobro). */
export async function findTicketRef(orderId, connection) {
  const rows = await query('SELECT id FROM tickets WHERE order_id = ?', [orderId], connection);
  return rows[0] ?? null;
}
