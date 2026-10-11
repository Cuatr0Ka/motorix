import { query } from '../config/db.js';

/** Importe decimal de la base ("850.00") → centavos enteros, para sumar sin errores de redondeo. */
export const toCents = (amount) => Math.round(Number(amount) * 100);

/** Centavos enteros → cadena decimal con dos decimales. */
export const fromCents = (cents) => (cents / 100).toFixed(2);

const toLine = (row) => ({ id: row.id, description: row.description, amount: fromCents(toCents(row.amount)) });

export async function listServices(orderId, connection) {
  const rows = await query(
    'SELECT id, description, amount FROM order_services WHERE order_id = ? ORDER BY id ASC',
    [orderId],
    connection,
  );
  return rows.map(toLine);
}

export async function listLabor(orderId, connection) {
  const rows = await query(
    'SELECT id, description, amount FROM order_labor WHERE order_id = ? ORDER BY id ASC',
    [orderId],
    connection,
  );
  return rows.map(toLine);
}

/** Totales calculados al leer (no se almacenan): servicios, mano de obra y total. */
export async function totals(orderId, connection) {
  const [services] = await query(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM order_services WHERE order_id = ?',
    [orderId],
    connection,
  );
  const [labor] = await query(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM order_labor WHERE order_id = ?',
    [orderId],
    connection,
  );
  const servicesCents = toCents(services.total);
  const laborCents = toCents(labor.total);
  return {
    services: fromCents(servicesCents),
    labor: fromCents(laborCents),
    total: fromCents(servicesCents + laborCents),
  };
}

/** Historial de cambios de estado, del más antiguo al más reciente. */
export async function listHistory(orderId, connection) {
  const rows = await query(
    `SELECT h.from_status, h.to_status, h.changed_at, u.id AS user_id, u.name AS user_name
       FROM order_status_history h
       JOIN users u ON u.id = h.changed_by
      WHERE h.order_id = ?
      ORDER BY h.changed_at ASC, h.id ASC`,
    [orderId],
    connection,
  );
  return rows.map((row) => ({
    fromStatus: row.from_status,
    toStatus: row.to_status,
    changedBy: { id: row.user_id, name: row.user_name },
    changedAt: row.changed_at,
  }));
}

export async function insertHistory({ orderId, fromStatus, toStatus, changedBy }, connection) {
  await query(
    'INSERT INTO order_status_history (order_id, from_status, to_status, changed_by) VALUES (?, ?, ?, ?)',
    [orderId, fromStatus ?? null, toStatus, changedBy],
    connection,
  );
}

// Tablas de líneas (lista blanca: nunca se arma SQL con nombres recibidos del exterior).
const LINE_TABLES = { services: 'order_services', labor: 'order_labor' };

function tableFor(kind) {
  const table = LINE_TABLES[kind];
  if (!table) throw new Error(`Tipo de línea desconocido: ${kind}`);
  return table;
}

/** Línea de la orden (siempre acotada por `order_id` para no tocar líneas de otra orden). */
export async function findLine(kind, orderId, lineId, connection) {
  const rows = await query(
    `SELECT id, description, amount FROM ${tableFor(kind)} WHERE id = ? AND order_id = ?`,
    [lineId, orderId],
    connection,
  );
  return rows[0] ? toLine(rows[0]) : null;
}

export async function insertLine(kind, orderId, { description, amount }, connection) {
  const result = await query(
    `INSERT INTO ${tableFor(kind)} (order_id, description, amount) VALUES (?, ?, ?)`,
    [orderId, description, amount],
    connection,
  );
  return result.insertId;
}

export async function updateLine(kind, orderId, lineId, fields, connection) {
  const assignments = [];
  const params = [];
  if (fields.description !== undefined) {
    assignments.push('description = ?');
    params.push(fields.description);
  }
  if (fields.amount !== undefined) {
    assignments.push('amount = ?');
    params.push(fields.amount);
  }
  if (assignments.length === 0) return;
  await query(
    `UPDATE ${tableFor(kind)} SET ${assignments.join(', ')} WHERE id = ? AND order_id = ?`,
    [...params, lineId, orderId],
    connection,
  );
}

export async function deleteLine(kind, orderId, lineId, connection) {
  await query(`DELETE FROM ${tableFor(kind)} WHERE id = ? AND order_id = ?`, [lineId, orderId], connection);
}
