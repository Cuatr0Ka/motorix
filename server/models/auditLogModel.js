import { query } from '../config/db.js';
import { limitOffset } from '../utils/pagination.js';

/**
 * Bitácora de acciones sensibles. Es de SOLO inserción y consulta: este módulo no ofrece ninguna función que
 * actualice o borre filas, y no existe ninguna ruta que lo haga (FR-024).
 */

const toEntry = (row) => ({
  id: row.id,
  createdAt: row.created_at,
  action: row.action,
  actor: row.actor_user_id === null ? null : { id: row.actor_user_id, username: row.username, name: row.name },
  entityType: row.entity_type,
  entityId: row.entity_id,
  summary: row.summary,
});

export async function insert({ actorUserId = null, action, entityType = null, entityId = null, summary }, connection) {
  const result = await query(
    'INSERT INTO audit_log (actor_user_id, action, entity_type, entity_id, summary) VALUES (?, ?, ?, ?, ?)',
    [actorUserId, action, entityType, entityId, summary],
    connection,
  );
  return result.insertId;
}

/** Consulta paginada, de la más reciente a la más antigua, con filtros por fecha, usuario y acción. */
export async function list({ from, to, userId, action, page, pageSize }, connection) {
  const conditions = [];
  const params = [];
  if (from) {
    conditions.push('a.created_at >= ?');
    params.push(from);
  }
  if (to) {
    conditions.push('a.created_at < DATE_ADD(?, INTERVAL 1 DAY)'); // `to` (AAAA-MM-DD) incluye todo ese día
    params.push(to);
  }
  if (userId) {
    conditions.push('a.actor_user_id = ?');
    params.push(userId);
  }
  if (action) {
    conditions.push('a.action = ?');
    params.push(action);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const [rows, totals] = await Promise.all([
    query(
      `SELECT a.id, a.created_at, a.action, a.actor_user_id, a.entity_type, a.entity_id, a.summary, u.username, u.name
         FROM audit_log a
         LEFT JOIN users u ON u.id = a.actor_user_id
         ${where}
        ORDER BY a.created_at DESC, a.id DESC
        LIMIT ${limit} OFFSET ${offset}`,
      params,
      connection,
    ),
    query(`SELECT COUNT(*) AS total FROM audit_log a ${where}`, params, connection),
  ]);
  return { items: rows.map(toEntry), total: Number(totals[0].total) };
}
