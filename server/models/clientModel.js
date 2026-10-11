import { query } from '../config/db.js';
import { toBool, toCamel } from '../utils/normalize.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const toClient = (row) => (row ? { ...toCamel(row), ...('active' in row ? { active: toBool(row.active) } : {}) } : null);

/** Listado paginado con búsqueda por nombre o teléfono y conteo de vehículos. */
export async function list({ search, page, pageSize }) {
  const params = [];
  let where = '';
  if (search) {
    where = 'WHERE (c.name LIKE ? OR c.phone LIKE ?)';
    params.push(likePattern(search), likePattern(search));
  }
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `SELECT c.id, c.name, c.phone, c.email, c.address, c.created_at,
            (SELECT COUNT(*) FROM vehicles v WHERE v.client_id = c.id) AS vehicle_count
       FROM clients c
       ${where}
      ORDER BY c.name ASC, c.id ASC
      LIMIT ${limit} OFFSET ${offset}`,
    params,
  );
  const [{ total }] = await query(`SELECT COUNT(*) AS total FROM clients c ${where}`, params);

  return {
    items: rows.map((row) => ({ ...toCamel(row), vehicleCount: Number(row.vehicle_count) })),
    total: Number(total),
  };
}

/** Cliente con sus vehículos (o null si no existe). */
export async function findById(id, connection) {
  const rows = await query(
    'SELECT id, name, phone, email, address, active, created_at, updated_at FROM clients WHERE id = ?',
    [id],
    connection,
  );
  if (!rows[0]) return null;

  const vehicles = await query(
    `SELECT id, brand, model, year, license_plate, current_mileage
       FROM vehicles WHERE client_id = ? ORDER BY brand ASC, model ASC, id ASC`,
    [id],
    connection,
  );
  return { ...toClient(rows[0]), vehicles: vehicles.map(toCamel) };
}

export async function exists(id, connection) {
  const rows = await query('SELECT id FROM clients WHERE id = ?', [id], connection);
  return rows.length > 0;
}

export async function findByEmail(email, excludeId = 0) {
  const rows = await query('SELECT id FROM clients WHERE email = ? AND id <> ? LIMIT 1', [email, excludeId]);
  return rows[0] ?? null;
}

/** Clientes con el mismo teléfono, comparando solo los dígitos. */
export async function findByPhone(phone, excludeId = 0) {
  const digits = phone.replace(/\D/g, '');
  return query(
    `SELECT id, name, phone FROM clients
      WHERE REGEXP_REPLACE(phone, '[^0-9]', '') = ? AND id <> ?
      ORDER BY id ASC LIMIT 10`,
    [digits, excludeId],
  );
}

const EDITABLE_COLUMNS = { name: 'name', phone: 'phone', email: 'email', address: 'address' };

/** Actualiza solo los campos presentes (lista blanca de columnas); `null` vacía el campo. */
export async function update(id, fields) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE_COLUMNS)) {
    if (fields[key] === undefined) continue;
    assignments.push(`${column} = ?`);
    params.push(fields[key]);
  }
  if (assignments.length === 0) return;
  await query(`UPDATE clients SET ${assignments.join(', ')} WHERE id = ?`, [...params, id]);
}

export async function create({ name, phone, email, address }) {
  const result = await query('INSERT INTO clients (name, phone, email, address) VALUES (?, ?, ?, ?)', [
    name,
    phone,
    email ?? null,
    address ?? null,
  ]);
  return result.insertId;
}
