import { query } from '../config/db.js';

const SELECT = `SELECT op.id, op.order_id, op.part_id, op.quantity, op.unit_price, p.code, p.name, p.unit
  FROM order_parts op
  JOIN parts p ON p.id = op.part_id`;

/** Importe decimal de la base ("180.00") → centavos enteros. */
const toCents = (amount) => Math.round(Number(amount) * 100);
const fromCents = (cents) => (cents / 100).toFixed(2);

/**
 * Línea completa (vista de administración y recepción). `unitPrice` es la instantánea del precio de venta;
 * `legacy` marca las líneas anteriores a los precios (precio 0), que no suman al total. Las respuestas para el
 * mecánico pasan por `presentOrderPart`, que quita los precios.
 */
const toLine = (row) => {
  const unitPriceCents = toCents(row.unit_price);
  return {
    id: row.id,
    partId: row.part_id,
    code: row.code,
    name: row.name,
    unit: row.unit,
    quantity: row.quantity,
    unitPrice: fromCents(unitPriceCents),
    amount: fromCents(row.quantity * unitPriceCents),
    legacy: unitPriceCents === 0,
  };
};

/** Refacciones usadas en la orden, en el orden en que se agregaron. */
export async function listByOrder(orderId, connection) {
  const rows = await query(`${SELECT} WHERE op.order_id = ? ORDER BY op.id ASC`, [orderId], connection);
  return rows.map(toLine);
}

/**
 * Con `forUpdate` la lectura es bloqueante y siempre ve lo último confirmado. Se usa dentro de las transacciones que
 * modifican la línea: en MySQL no cambia el resultado (la orden ya está bloqueada), y en bases con aislamiento por
 * instantánea (TiDB) evita leer una foto vieja y duplicar la línea.
 */
export async function findLine(orderId, lineId, connection, { forUpdate = false } = {}) {
  const rows = await query(
    `${SELECT} WHERE op.order_id = ? AND op.id = ?${forUpdate ? ' FOR UPDATE' : ''}`,
    [orderId, lineId],
    connection,
  );
  return rows[0] ? toLine(rows[0]) : null;
}

export async function findByOrderAndPart(orderId, partId, connection, { forUpdate = false } = {}) {
  const rows = await query(
    `${SELECT} WHERE op.order_id = ? AND op.part_id = ?${forUpdate ? ' FOR UPDATE' : ''}`,
    [orderId, partId],
    connection,
  );
  return rows[0] ? toLine(rows[0]) : null;
}

/** `unitPrice` es el precio de venta vigente de la refacción al agregarla (cadena decimal); queda guardado en la línea. */
export async function insert({ orderId, partId, quantity, unitPrice = 0, createdBy }, connection) {
  const result = await query(
    'INSERT INTO order_parts (order_id, part_id, quantity, unit_price, created_by) VALUES (?, ?, ?, ?, ?)',
    [orderId, partId, quantity, unitPrice, createdBy],
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
