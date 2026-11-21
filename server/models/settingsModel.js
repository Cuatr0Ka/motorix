import { query } from '../config/db.js';

/** Todas las claves guardadas como un objeto `{ clave: valor }`. */
export async function getAll(connection) {
  const rows = await query('SELECT setting_key, setting_value FROM settings', [], connection);
  return Object.fromEntries(rows.map((row) => [row.setting_key, row.setting_value]));
}

/**
 * Guarda varias claves en UNA sola sentencia (atómica: nunca queda un cambio a medias) con
 * `INSERT ... ON DUPLICATE KEY UPDATE`. `entries` es un objeto `{ clave: valor }`.
 */
export async function upsertMany(entries, updatedBy, connection) {
  const keys = Object.keys(entries);
  if (keys.length === 0) return;
  const placeholders = keys.map(() => '(?, ?, ?)').join(', ');
  const params = keys.flatMap((key) => [key, String(entries[key]), updatedBy]);
  await query(
    `INSERT INTO settings (setting_key, setting_value, updated_by) VALUES ${placeholders}
     ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)`,
    params,
    connection,
  );
}
