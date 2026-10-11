import { AppError } from '../utils/AppError.js';

/**
 * Reglas de transición de estado de las órdenes de servicio. Módulo puro: no accede a la base de
 * datos ni a Express, para poder probarlo de forma exhaustiva (CA-8).
 */

export const ORDER_STATUSES = Object.freeze([
  'RECIBIDO',
  'DIAGNOSTICO',
  'EN_REPARACION',
  'ESPERANDO_REFACCION',
  'TERMINADO',
  'ENTREGADO',
]);

/** Etiquetas en español para los mensajes que ve la persona usuaria. */
export const ORDER_STATUS_LABELS = Object.freeze({
  RECIBIDO: 'Recibido',
  DIAGNOSTICO: 'Diagnóstico',
  EN_REPARACION: 'En reparación',
  ESPERANDO_REFACCION: 'Esperando refacción',
  TERMINADO: 'Terminado',
  ENTREGADO: 'Entregado',
});

const label = (status) => ORDER_STATUS_LABELS[status] ?? status;

/** Secuencia estricta, sin saltos ni retrocesos; ESPERANDO_REFACCION solo regresa a EN_REPARACION. */
const TRANSITIONS = Object.freeze({
  RECIBIDO: ['DIAGNOSTICO'],
  DIAGNOSTICO: ['EN_REPARACION', 'ESPERANDO_REFACCION'],
  EN_REPARACION: ['TERMINADO', 'ESPERANDO_REFACCION'],
  ESPERANDO_REFACCION: ['EN_REPARACION'],
  TERMINADO: ['ENTREGADO'],
  ENTREGADO: [],
});

/** Estados a los que se puede pasar desde `status` (lista vacía si no hay salida o no existe). */
export function allowedNext(status) {
  return [...(TRANSITIONS[status] ?? [])];
}

/** Lanza `INVALID_TRANSITION` (422) si el paso de `from` a `to` no está permitido. */
export function assertTransition(from, to) {
  if (allowedNext(from).includes(to)) return;
  const allowed = allowedNext(from);
  const hint =
    allowed.length > 0
      ? `Desde ${label(from)} solo se puede pasar a: ${allowed.map(label).join(', ')}.`
      : `Una orden en ${label(from)} ya no admite cambios de estado.`;
  throw AppError.unprocessable('INVALID_TRANSITION', `Ese cambio de estado no está permitido. ${hint}`, {
    currentStatus: from,
    allowed,
  });
}

/**
 * Indica si quien actúa puede ejecutar la transición hacia `to` sobre `order`.
 * Hasta TERMINADO: ADMIN o el mecánico asignado. A ENTREGADO: ADMIN o RECEPTIONIST.
 */
export function canActorTransition({ role, userId, order, to }) {
  if (to === 'ENTREGADO') return role === 'ADMIN' || role === 'RECEPTIONIST';
  if (role === 'ADMIN') return true;
  return role === 'MECHANIC' && order.mechanicId != null && order.mechanicId === userId;
}

/** Transiciones válidas desde el estado actual que además puede ejecutar quien consulta. */
export function allowedFor({ role, userId, order }) {
  return allowedNext(order.status).filter((to) => canActorTransition({ role, userId, order, to }));
}
