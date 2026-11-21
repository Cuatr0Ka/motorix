import * as auditLogModel from '../models/auditLogModel.js';

/** Acciones sensibles que registra la bitácora (data-model.md). */
export const ACTIONS = Object.freeze({
  LOGIN_FAILED: 'LOGIN_FAILED',
  ACCOUNT_LOCKED: 'ACCOUNT_LOCKED',
  PASSWORD_CHANGED: 'PASSWORD_CHANGED',
  USER_CREATED: 'USER_CREATED',
  USER_DEACTIVATED: 'USER_DEACTIVATED',
  USER_ACTIVATED: 'USER_ACTIVATED',
  USER_ROLE_CHANGED: 'USER_ROLE_CHANGED',
  SETTINGS_CHANGED: 'SETTINGS_CHANGED',
  SERVICE_TYPE_CHANGED: 'SERVICE_TYPE_CHANGED',
  PART_PRICE_CHANGED: 'PART_PRICE_CHANGED',
  PAYMENT_CANCELLED: 'PAYMENT_CANCELLED',
  TERMS_ACCEPTED: 'TERMS_ACCEPTED',
});

const SUMMARY_MAX = 255;

/**
 * Cadenas que NUNCA deben llegar a la bitácora (FR-025): contraseñas, hashes, tokens y números de tarjeta (13 a 19
 * dígitos seguidos o separados por espacios o guiones).
 */
const RESERVED = /contrase[ñn]a\s*[:=]|password|passwd|hash|token|bearer|jwt|\b(?:\d[ -]?){13,19}\b/i;

/** Un resumen es válido si no contiene datos reservados. */
export function isSafeSummary(summary) {
  return typeof summary === 'string' && summary.trim() !== '' && !RESERVED.test(summary);
}

/**
 * Registra una acción sensible. Se llama DESPUÉS de la acción y NO propaga errores: si la bitácora falla, la operación
 * ya hecha no se cancela (se avisa en el registro del servidor). Devuelve `true` si quedó registrada.
 *
 * `actor` es el usuario que hizo la acción, o al que se atribuye (por ejemplo, la cuenta de un inicio de sesión fallido).
 */
export async function record({ actor, action, entityType = null, entityId = null, summary }) {
  try {
    if (!Object.values(ACTIONS).includes(action)) {
      throw new Error(`Acción de bitácora desconocida: ${action}`);
    }
    if (!isSafeSummary(summary)) {
      throw new Error(`El resumen de la bitácora (${action}) está vacío o contiene datos reservados.`);
    }
    await auditLogModel.insert({
      actorUserId: actor?.id ?? null,
      action,
      entityType,
      entityId,
      summary: summary.trim().slice(0, SUMMARY_MAX),
    });
    return true;
  } catch (error) {
    // La bitácora no puede romper la operación que ya se hizo.
    console.error(`[bitácora] No se pudo registrar ${action}: ${error.message}`);
    return false;
  }
}

/** Consulta de la bitácora (solo administración). */
export async function list(filters) {
  return auditLogModel.list(filters);
}
