import { query } from '../config/db.js';

/** Claves de aviso que el usuario ya marcó como leídas. */
export async function listReadKeys(userId, connection) {
  const rows = await query('SELECT notice_key FROM notification_reads WHERE user_id = ?', [userId], connection);
  return new Set(rows.map((row) => row.notice_key));
}

/**
 * Marca avisos como leídos. `INSERT IGNORE` sobre la llave primaria (usuario, clave): repetir o hacerlo en
 * paralelo deja una sola fila y no falla. Devuelve cuántas filas nuevas se insertaron.
 */
export async function insertIgnore(userId, keys, connection) {
  if (keys.length === 0) return 0;
  const placeholders = keys.map(() => '(?, ?)').join(', ');
  const params = keys.flatMap((key) => [userId, key]);
  const result = await query(
    `INSERT IGNORE INTO notification_reads (user_id, notice_key) VALUES ${placeholders}`,
    params,
    connection,
  );
  return result.affectedRows;
}
