import { query } from '../config/db.js';

const SELECT = `SELECT op.id, op.order_id, op.part_id, op.quantity, p.code, p.name, p.unit
  FROM order_parts op
  JOIN parts p ON p.id = op.part_id`;

const toLine = (row) => ({
  id: row.id,
  partId: row.part_id,
  code: row.code,
  name: row.name,
  unit: row.unit,
  quantity: row.quantity,
});

/** Refacciones usadas en la orden, en el orden en que se agregaron. */
export async function listByOrder(orderId, connection) {
  const rows = await query(`${SELECT} WHERE op.order_id = ? ORDER BY op.id ASC`, [orderId], connection);
  return rows.map(toLine);
}

export async function findLine(orderId, lineId, connection) {
  const rows = await query(`${SELECT} WHERE op.order_id = ? AND op.id = ?`, [orderId, lineId], connection);
  return rows[0] ? toLine(rows[0]) : null;
}

export async function findByOrderAndPart(orderId, partId, connection) {
  const rows = await query(`${SELECT} WHERE op.order_id = ? AND op.part_id = ?`, [orderId, partId], connection);
  return rows[0] ? toLine(rows[0]) : null;
}

export async function insert({ orderId, partId, quantity, createdBy }, connection) {
  const result = await query(
    'INSERT INTO order_parts (order_id, part_id, quantity, created_by) VALUES (?, ?, ?, ?)',
    [orderId, partId, quantity, createdBy],
    connection,
  );
  return result.insertId;
}

export async function updateQuantity(id, quantity, connection) {
  await query('UPDATE order_parts SET quantity = ? WHERE id = ?', [quantity, id], connection);
}

/** Quita la línea de uso. Los movimientos de inventario ya registrados se conservan. */
export async function deleteLine(id, connection) {
  await query('DELETE FROM order_parts WHERE id = ?', [id], connection);
}
