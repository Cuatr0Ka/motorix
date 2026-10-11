import { query } from '../config/db.js';
import { toBool, toCamel } from '../utils/normalize.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const PUBLIC_COLUMNS =
  'id, username, name, email, role, active, created_at, updated_at';

/** Usuario sin datos sensibles (nunca incluye password_hash). */
function toUser(row) {
  if (!row) return null;
  const user = toCamel(row);
  user.active = toBool(user.active);
  return user;
}

export async function findById(id, connection) {
  const rows = await query(`SELECT ${PUBLIC_COLUMNS} FROM users WHERE id = ?`, [id], connection);
  return toUser(rows[0]);
}

/** Listado paginado con búsqueda por usuario, nombre o correo y filtros de rol y estado. */
export async function list({ search, role, active, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    conditions.push('(username LIKE ? OR name LIKE ? OR email LIKE ?)');
    params.push(pattern, pattern, pattern);
  }
  if (role) {
    conditions.push('role = ?');
    params.push(role);
  }
  if (active !== undefined) {
    conditions.push('active = ?');
    params.push(active ? 1 : 0);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `SELECT ${PUBLIC_COLUMNS} FROM users ${where} ORDER BY name ASC, id ASC LIMIT ${limit} OFFSET ${offset}`,
    params,
  );
  const [{ total }] = await query(`SELECT COUNT(*) AS total FROM users ${where}`, params);
  return { items: rows.map(toUser), total: Number(total) };
}

export async function findByUsername(username, excludeId = 0) {
  const rows = await query('SELECT id FROM users WHERE username = ? AND id <> ? LIMIT 1', [username, excludeId]);
  return rows[0] ?? null;
}

export async function findByEmail(email, excludeId = 0) {
  const rows = await query('SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1', [email, excludeId]);
  return rows[0] ?? null;
}

export async function create({ username, name, email, passwordHash, role }) {
  const result = await query(
    'INSERT INTO users (username, name, email, password_hash, role) VALUES (?, ?, ?, ?, ?)',
    [username, name, email, passwordHash, role],
  );
  return result.insertId;
}

/** Bloquea (FOR UPDATE) las filas de los administradores activos, siempre en orden de id para evitar interbloqueos. */
export async function lockActiveAdmins(connection) {
  const rows = await query(
    "SELECT id FROM users WHERE role = 'ADMIN' AND active = 1 ORDER BY id ASC FOR UPDATE",
    [],
    connection,
  );
  return rows.map((row) => row.id);
}

/** Lee un usuario bloqueando su fila dentro de una transacción. */
export async function findByIdForUpdate(id, connection) {
  const rows = await query(`SELECT ${PUBLIC_COLUMNS} FROM users WHERE id = ? FOR UPDATE`, [id], connection);
  return toUser(rows[0]);
}

const EDITABLE_COLUMNS = { name: 'name', email: 'email', role: 'role', active: 'active' };

/** Actualiza solo los campos presentes (lista blanca de columnas). */
export async function update(id, fields, connection) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE_COLUMNS)) {
    if (fields[key] === undefined) continue;
    assignments.push(`${column} = ?`);
    params.push(key === 'active' ? (fields[key] ? 1 : 0) : fields[key]);
  }
  if (assignments.length === 0) return;
  await query(`UPDATE users SET ${assignments.join(', ')} WHERE id = ?`, [...params, id], connection);
}

export async function getPasswordHash(id) {
  const rows = await query('SELECT password_hash FROM users WHERE id = ?', [id]);
  return rows[0]?.password_hash ?? null;
}

export async function updatePassword(id, passwordHash) {
  await query('UPDATE users SET password_hash = ? WHERE id = ?', [passwordHash, id]);
}

/**
 * Suma un intento fallido. Al llegar a `maxAttempts` bloquea la cuenta `lockMinutes` minutos
 * (con la hora de la base de datos) y reinicia el contador. Devuelve si quedó bloqueada.
 */
export async function registerFailedAttempt(id, maxAttempts, lockMinutes) {
  await query(
    `UPDATE users
        SET locked_until = IF(failed_login_attempts + 1 >= ?, NOW() + INTERVAL ? MINUTE, locked_until),
            failed_login_attempts = IF(failed_login_attempts + 1 >= ?, 0, failed_login_attempts + 1)
      WHERE id = ?`,
    [maxAttempts, lockMinutes, maxAttempts, id],
  );
  const rows = await query(
    `SELECT (locked_until IS NOT NULL AND locked_until > NOW()) AS is_locked,
            GREATEST(TIMESTAMPDIFF(SECOND, NOW(), locked_until), 0) AS seconds_left
       FROM users WHERE id = ?`,
    [id],
  );
  return { locked: Boolean(rows[0]?.is_locked), lockSecondsLeft: Number(rows[0]?.seconds_left) || 0 };
}

/** Reinicia el contador de fallos y limpia el bloqueo tras un acceso correcto. */
export async function resetFailures(id) {
  await query('UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = ?', [id]);
}

/**
 * Busca por identificador de acceso: si contiene `@` se trata como correo; si no, como usuario.
 * Devuelve también los datos de acceso (hash y bloqueo) para uso exclusivo del servicio de autenticación.
 */
export async function findByIdentifier(identifier) {
  const column = identifier.includes('@') ? 'email' : 'username';
  const rows = await query(
    `SELECT ${PUBLIC_COLUMNS}, password_hash, failed_login_attempts,
            (locked_until IS NOT NULL AND locked_until > NOW()) AS is_locked,
            GREATEST(TIMESTAMPDIFF(SECOND, NOW(), locked_until), 0) AS lock_seconds_left
       FROM users WHERE ${column} = ?`,
    [identifier],
  );
  if (!rows[0]) return null;
  const { passwordHash, failedLoginAttempts, isLocked, lockSecondsLeft, ...rest } = toCamel(rows[0]);
  return {
    user: toUser(rest),
    passwordHash,
    failedLoginAttempts,
    isLocked: Boolean(isLocked),
    lockSecondsLeft: Number(lockSecondsLeft) || 0,
  };
}

/** Mecánico activo (rol MECHANIC) por id, solo con los datos necesarios para asignarlo a una orden. */
export async function findActiveMechanic(id, connection) {
  const rows = await query(
    "SELECT id, name, username FROM users WHERE id = ? AND role = 'MECHANIC' AND active = 1",
    [id],
    connection,
  );
  return rows[0] ?? null;
}

/** Mecánicos activos para elegir a quién asignar una orden (nunca incluye correo ni hash). */
export async function listActiveMechanics() {
  return query("SELECT id, name, username FROM users WHERE role = 'MECHANIC' AND active = 1 ORDER BY name ASC, id ASC");
}
