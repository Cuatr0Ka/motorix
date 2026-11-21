/**
 * Reglas puras de las notificaciones internas y de los clientes por avisar (Sprint 6). No acceden a la base:
 * solo deciden qué es un aviso, cómo se identifica y qué roles lo ven.
 */

/** Días calendario sin cambio de estado a partir de los cuales una orden abierta se considera detenida (D-01). */
export const STALLED_DAYS = 3;

/** Tipos de aviso. El stock se muestra en dos niveles: bajo y agotado. */
export const NOTICE_TYPES = Object.freeze({
  MAINT_UPCOMING: 'MAINT_UPCOMING',
  MAINT_OVERDUE: 'MAINT_OVERDUE',
  APPT_TODAY: 'APPT_TODAY',
  STOCK_LOW: 'STOCK_LOW',
  STOCK_OUT: 'STOCK_OUT',
  STALLED: 'STALLED',
});

/** Orden en que se devuelven los grupos de avisos (contracts/api-rest.md). */
export const GROUP_ORDER = Object.freeze([
  'MAINT_OVERDUE',
  'STOCK_OUT',
  'STALLED',
  'APPT_TODAY',
  'MAINT_UPCOMING',
  'STOCK_LOW',
]);

/** Motivos por los que se avisa a un cliente. */
export const CLIENT_NOTICE_REASONS = Object.freeze({
  ORDER_READY: 'ORDER_READY',
  APPT_TOMORROW: 'APPT_TOMORROW',
  MAINT_UPCOMING: 'MAINT_UPCOMING',
  MAINT_OVERDUE: 'MAINT_OVERDUE',
});

/** Estados de una orden abierta que pueden quedar detenidos. TERMINADO se avisa por la lista de clientes. */
export const STALLED_STATUSES = Object.freeze(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION']);

/** Longitud máxima de la clave de un aviso (columna `notice_key`). */
export const NOTICE_KEY_MAX = 60;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Número de días (calendario local, sin hora) de una fecha para poder restar días completos. */
function toDayNumber(value) {
  const date = value instanceof Date ? value : new Date(value);
  return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DAY_MS);
}

/** Días calendario transcurridos entre el último cambio y hoy (nunca negativo). */
export function daysSince(lastChangeAt, today = new Date()) {
  return Math.max(0, toDayNumber(today) - toDayNumber(lastChangeAt));
}

/**
 * Una orden está detenida si está abierta (Recibida, Diagnóstico, En reparación o Esperando refacción) y
 * lleva más de `STALLED_DAYS` días calendario sin cambio de estado.
 */
export function isStalledOrder({ status, lastChangeAt, today = new Date() }) {
  if (!STALLED_STATUSES.includes(status)) return false;
  if (lastChangeAt === null || lastChangeAt === undefined) return false;
  return daysSince(lastChangeAt, today) > STALLED_DAYS;
}

/** Clave estable de un aviso: `TIPO:id` o `TIPO:id:variante` (por ejemplo `STALLED:5:31`). */
export function buildNoticeKey(type, id, variant) {
  return variant === undefined || variant === null ? `${type}:${id}` : `${type}:${id}:${variant}`;
}

const KEY_PATTERN = new RegExp(String.raw`^(${Object.values(NOTICE_TYPES).join('|')}):[1-9]\d{0,9}(:\d{1,10})?$`);

/** Una clave es válida si tiene la forma de las claves de aviso y cabe en la columna. */
export function isValidNoticeKey(text) {
  return typeof text === 'string' && text.length <= NOTICE_KEY_MAX && KEY_PATTERN.test(text);
}

/** Tipos de aviso que un rol puede recibir (el servidor decide; la interfaz no es seguridad). */
export function typesForRole(role) {
  if (role === 'ADMIN') return Object.values(NOTICE_TYPES);
  if (role === 'RECEPTIONIST') {
    return Object.values(NOTICE_TYPES).filter((type) => type !== 'STOCK_LOW' && type !== 'STOCK_OUT');
  }
  if (role === 'MECHANIC') return [NOTICE_TYPES.STALLED];
  return [];
}
