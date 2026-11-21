import { query } from '../config/db.js';

const toNotice = (row) => ({
  id: row.id,
  clientId: row.client_id,
  reason: row.reason,
  factId: row.fact_id,
  notifiedBy: row.notified_by,
  notifiedAt: row.notified_at,
});

/** Aviso ya registrado para un hecho (motivo e identificador), o null. */
export async function findByFact(reason, factId, connection) {
  const rows = await query(
    'SELECT id, client_id, reason, fact_id, notified_by, notified_at FROM client_notices WHERE reason = ? AND fact_id = ?',
    [reason, factId],
    connection,
  );
  return rows[0] ? toNotice(rows[0]) : null;
}

/**
 * Registra el aviso a un cliente. `INSERT IGNORE` sobre `uq_client_notices_fact`: si ya existía (por ejemplo
 * otra persona lo marcó un instante antes) no falla. Devuelve `true` solo si esta llamada creó la fila.
 */
export async function insertIgnore({ clientId, reason, factId, notifiedBy }, connection) {
  const result = await query(
    'INSERT IGNORE INTO client_notices (client_id, reason, fact_id, notified_by) VALUES (?, ?, ?, ?)',
    [clientId, reason, factId, notifiedBy],
    connection,
  );
  return result.affectedRows === 1;
}

/** Pares (motivo, hecho) ya avisados, como conjunto de textos `MOTIVO:id`. */
export async function listNoticedFacts(connection) {
  const rows = await query('SELECT reason, fact_id FROM client_notices', [], connection);
  return new Set(rows.map((row) => `${row.reason}:${row.fact_id}`));
}
