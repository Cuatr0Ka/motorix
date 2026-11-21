import { query } from '../config/db.js';

const toVersion = (row) =>
  row ? { id: row.id, version: row.version, title: row.title, body: row.body, publishedAt: row.published_at } : null;

/** Versión vigente de los términos: la publicada más recientemente. */
export async function findCurrent(connection) {
  const rows = await query(
    'SELECT id, version, title, body, published_at FROM terms_versions ORDER BY published_at DESC, id DESC LIMIT 1',
    [],
    connection,
  );
  return toVersion(rows[0]);
}

export async function findById(id, connection) {
  const rows = await query('SELECT id, version, title, body, published_at FROM terms_versions WHERE id = ?', [id], connection);
  return toVersion(rows[0]);
}

export async function hasAccepted(userId, versionId, connection) {
  const rows = await query(
    'SELECT 1 AS accepted FROM terms_acceptances WHERE user_id = ? AND terms_version_id = ? LIMIT 1',
    [userId, versionId],
    connection,
  );
  return rows.length > 0;
}

/** Registra la aceptación; `INSERT IGNORE` sobre la clave única hace que dos solicitudes simultáneas dejen una sola fila. */
export async function insertAcceptanceIgnore(userId, versionId, connection) {
  const result = await query(
    'INSERT IGNORE INTO terms_acceptances (user_id, terms_version_id) VALUES (?, ?)',
    [userId, versionId],
    connection,
  );
  return result.affectedRows > 0;
}

export async function findAcceptance(userId, versionId, connection) {
  const rows = await query(
    'SELECT accepted_at FROM terms_acceptances WHERE user_id = ? AND terms_version_id = ?',
    [userId, versionId],
    connection,
  );
  return rows[0]?.accepted_at ?? null;
}

/** Aceptaciones de una versión (paginadas, la más reciente primero) y cuántos usuarios activos faltan por aceptar. */
export async function listAcceptances(versionId, { page, pageSize }, connection) {
  const [{ total }] = await query('SELECT COUNT(*) AS total FROM terms_acceptances WHERE terms_version_id = ?', [versionId], connection);
  const [{ pending }] = await query(
    `SELECT COUNT(*) AS pending FROM users u
      WHERE u.active = 1
        AND NOT EXISTS (SELECT 1 FROM terms_acceptances a WHERE a.user_id = u.id AND a.terms_version_id = ?)`,
    [versionId],
    connection,
  );
  const rows = await query(
    `SELECT u.id AS user_id, u.username, u.name, a.accepted_at
       FROM terms_acceptances a JOIN users u ON u.id = a.user_id
      WHERE a.terms_version_id = ?
      ORDER BY a.accepted_at DESC, a.id DESC
      LIMIT ${Number(pageSize)} OFFSET ${(Number(page) - 1) * Number(pageSize)}`,
    [versionId],
    connection,
  );
  return {
    items: rows.map((row) => ({ userId: row.user_id, username: row.username, name: row.name, acceptedAt: row.accepted_at })),
    total: Number(total),
    pending: Number(pending),
  };
}
