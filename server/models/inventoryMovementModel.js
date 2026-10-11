import { query } from '../config/db.js';
import { formatFolio } from '../utils/orderFolio.js';
import { limitOffset } from '../utils/pagination.js';

// Tabla de solo agregar: este módulo no ofrece actualizar ni borrar movimientos.

const SELECT = `SELECT m.id, m.part_id, m.type, m.quantity, m.reason, m.order_id, m.created_at,
       u.id AS user_id, u.name AS user_name
  FROM inventory_movements m
  JOIN users u ON u.id = m.created_by`;

const toMovement = (row) => ({
  id: Number(row.id),
  partId: row.part_id,
  type: row.type,
  quantity: row.quantity,
  reason: row.reason,
  createdAt: row.created_at,
  order: row.order_id ? { id: row.order_id, folio: formatFolio(row.order_id) } : null,
  createdBy: { id: row.user_id, name: row.user_name },
});

export async function insert({ partId, type, quantity, reason, orderId, createdBy }, connection) {
  const result = await query(
    'INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by) VALUES (?, ?, ?, ?, ?, ?)',
    [partId, type, quantity, reason ?? null, orderId ?? null, createdBy],
    connection,
  );
  return Number(result.insertId);
}

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE m.id = ?`, [id], connection);
  return rows[0] ? toMovement(rows[0]) : null;
}

/** Movimientos de una refacción, el más reciente primero. */
export async function listByPart(partId, { page, pageSize }) {
  const { limit, offset } = limitOffset(page, pageSize);
  const rows = await query(
    `${SELECT} WHERE m.part_id = ? ORDER BY m.id DESC LIMIT ${limit} OFFSET ${offset}`,
    [partId],
  );
  const [{ total }] = await query('SELECT COUNT(*) AS total FROM inventory_movements WHERE part_id = ?', [partId]);
  return { items: rows.map(toMovement), total: Number(total) };
}
