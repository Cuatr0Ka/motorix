import { query } from '../config/db.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const COLUMNS = 'id, code, name, description, unit, stock, min_stock, active';

/** Estado de stock: Agotada (cero), Baja (en o bajo el mínimo) o Suficiente. Con mínimo 0 solo alerta al llegar a cero. */
export function stockStatusOf(stock, minStock) {
  if (stock === 0) return 'AGOTADO';
  if (stock <= minStock) return 'BAJO';
  return 'SUFICIENTE';
}

/** Fila → refacción completa (vista del administrador). */
export const toPart = (row) => ({
  id: row.id,
  code: row.code,
  name: row.name,
  description: row.description,
  unit: row.unit,
  stock: row.stock,
  minStock: row.min_stock,
  active: Boolean(row.active),
  stockStatus: stockStatusOf(row.stock, row.min_stock),
});

/** Proyección reducida del mecánico: código, nombre, unidad y existencia. */
export const toMechanicPart = (row) => ({
  id: row.id,
  code: row.code,
  name: row.name,
  unit: row.unit,
  stock: row.stock,
});

const STOCK_CONDITIONS = {
  AGOTADO: 'stock = 0',
  BAJO: 'stock > 0 AND stock <= min_stock',
  SUFICIENTE: 'stock > min_stock',
};

/**
 * Listado paginado por nombre. Filtros: búsqueda por código o nombre, estado de stock y activas.
 * Los valores de `stockStatus` vienen de una lista blanca, nunca se interpolan datos del exterior.
 */
export async function list({ search, stockStatus, active, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    conditions.push('(code LIKE ? OR name LIKE ?)');
    params.push(pattern, pattern);
  }
  if (stockStatus) conditions.push(`(${STOCK_CONDITIONS[stockStatus]})`);
  if (active !== undefined) {
    conditions.push('active = ?');
    params.push(active ? 1 : 0);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `SELECT ${COLUMNS} FROM parts ${where} ORDER BY name ASC, id ASC LIMIT ${limit} OFFSET ${offset}`,
    params,
  );
  const [{ total }] = await query(`SELECT COUNT(*) AS total FROM parts ${where}`, params);
  return { rows, total: Number(total) };
}

export async function findById(id, connection) {
  const rows = await query(`SELECT ${COLUMNS} FROM parts WHERE id = ?`, [id], connection);
  return rows[0] ?? null;
}

/** Bloquea la fila de la refacción dentro de una transacción y devuelve su estado vigente. */
export async function lockById(id, connection) {
  const rows = await query(`SELECT ${COLUMNS} FROM parts WHERE id = ? FOR UPDATE`, [id], connection);
  return rows[0] ?? null;
}

export async function insert({ code, name, description, unit, minStock }, connection) {
  const result = await query(
    'INSERT INTO parts (code, name, description, unit, stock, min_stock) VALUES (?, ?, ?, ?, 0, ?)',
    [code, name, description ?? null, unit, minStock],
    connection,
  );
  return result.insertId;
}

// Columnas editables (lista blanca). El código y el stock no se editan por esta vía.
const EDITABLE = { name: 'name', description: 'description', unit: 'unit', minStock: 'min_stock', active: 'active' };

export async function update(id, fields, connection) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      params.push(key === 'active' ? (fields[key] ? 1 : 0) : fields[key]);
    }
  }
  if (assignments.length === 0) return false;
  await query(`UPDATE parts SET ${assignments.join(', ')} WHERE id = ?`, [...params, id], connection);
  return true;
}

/**
 * Suma `delta` (con signo) al stock solo si el resultado no es negativo (RN-8). Devuelve true si se
 * aplicó. Es la única operación que modifica `parts.stock` y solo debe llamarla el servicio de inventario.
 */
export async function applyDelta(id, delta, connection) {
  const result = await query(
    'UPDATE parts SET stock = CAST(stock AS SIGNED) + ? WHERE id = ? AND CAST(stock AS SIGNED) + ? >= 0',
    [delta, id, delta],
    connection,
  );
  return result.affectedRows > 0;
}

/** Refacciones activas con stock en o bajo el mínimo; las agotadas primero (alertas de stock bajo). */
export async function listAlerts(connection) {
  return query(
    `SELECT ${COLUMNS} FROM parts WHERE active = 1 AND stock <= min_stock ORDER BY (stock = 0) DESC, name ASC, id ASC`,
    [],
    connection,
  );
}
