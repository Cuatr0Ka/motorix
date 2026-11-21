import { query } from '../config/db.js';

const toType = (row) => ({
  id: row.id,
  name: row.name,
  intervalDays: row.interval_days,
  intervalKm: row.interval_km,
  active: Boolean(row.active),
  ...(row.in_use !== undefined ? { inUse: Number(row.in_use) } : {}),
});

const SELECT_WITH_USE = `SELECT t.id, t.name, t.interval_days, t.interval_km, t.active,
    (SELECT COUNT(*) FROM order_services s WHERE s.service_type_id = t.id) AS in_use
  FROM service_types t`;

/** Todos los tipos (también los desactivados) con el número de líneas que los usan; `active` filtra si se indica. */
export async function list({ active } = {}, connection) {
  const where = active === undefined ? '' : 'WHERE t.active = ?';
  const rows = await query(`${SELECT_WITH_USE} ${where} ORDER BY t.name ASC, t.id ASC`, active === undefined ? [] : [active ? 1 : 0], connection);
  return rows.map(toType);
}

/** Solo los activos, para elegirlos en una línea de servicio. */
export async function listActive(connection) {
  const rows = await query(
    'SELECT id, name, interval_days, interval_km, active FROM service_types WHERE active = 1 ORDER BY name ASC, id ASC',
    [],
    connection,
  );
  return rows.map(toType);
}

export async function findById(id, connection) {
  const rows = await query(`${SELECT_WITH_USE} WHERE t.id = ?`, [id], connection);
  return rows[0] ? toType(rows[0]) : null;
}

/** Busca por nombre sin distinguir mayúsculas ni acentos de mayúsculas; `excludeId` evita chocar consigo mismo. */
export async function findByName(name, excludeId, connection) {
  const rows = await query(
    'SELECT id FROM service_types WHERE LOWER(name) = LOWER(?) AND id <> ? LIMIT 1',
    [name, excludeId ?? 0],
    connection,
  );
  return rows[0] ?? null;
}

export async function insert({ name, intervalDays, intervalKm }, connection) {
  const result = await query(
    'INSERT INTO service_types (name, interval_days, interval_km) VALUES (?, ?, ?)',
    [name, intervalDays ?? null, intervalKm ?? null],
    connection,
  );
  return result.insertId;
}

/** Actualiza solo los campos enviados. No existe borrado: un tipo en uso solo se desactiva. */
export async function update(id, fields, connection) {
  const columns = { name: 'name', intervalDays: 'interval_days', intervalKm: 'interval_km' };
  const assignments = [];
  const params = [];
  for (const [field, column] of Object.entries(columns)) {
    if (fields[field] === undefined) continue;
    assignments.push(`${column} = ?`);
    params.push(fields[field]);
  }
  if (fields.active !== undefined) {
    assignments.push('active = ?');
    params.push(fields.active ? 1 : 0);
  }
  if (assignments.length === 0) return;
  await query(`UPDATE service_types SET ${assignments.join(', ')} WHERE id = ?`, [...params, id], connection);
}

/** Tipos (distintos) de las líneas de servicio de una orden, para proponer el próximo mantenimiento. */
export async function listByOrder(orderId, connection) {
  const rows = await query(
    `SELECT DISTINCT t.id, t.name, t.interval_days, t.interval_km, t.active
       FROM order_services s JOIN service_types t ON t.id = s.service_type_id
      WHERE s.order_id = ? ORDER BY t.id ASC`,
    [orderId],
    connection,
  );
  return rows.map(toType);
}
