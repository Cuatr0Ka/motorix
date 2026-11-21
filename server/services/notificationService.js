import * as notificationReadModel from '../models/notificationReadModel.js';
import * as maintenanceService from './maintenanceService.js';
import { GROUP_ORDER, NOTICE_TYPES, buildNoticeKey, typesForRole } from './noticeRules.js';

/** Máximo de avisos que se listan por tipo; el total real de cada tipo se informa aparte. */
const LIST_LIMIT = 50;

/** Máximo de avisos que se revisan por tipo para contar los no leídos con exactitud (SC-007). */
const SCAN_LIMIT = 1000;

/**
 * Los avisos NO se guardan: se calculan al consultar con los mismos servicios que usan el panel de control, la
 * lista de Mantenimientos y las alertas de stock, para que los números coincidan entre pantallas (FR-005).
 * Cada cargador devuelve `{ total, notices }` con todos los avisos revisados del tipo (sin la marca de lectura).
 */

/** Detalle de un mantenimiento: descripción, vehículo y, si el rol lo recibe, el nombre del cliente. */
function maintenanceDetail(item) {
  const vehicle = `${item.vehicle.brand} ${item.vehicle.model} ${item.vehicle.licensePlate}`;
  const parts = [item.description, vehicle];
  if (item.client) parts.push(item.client.name);
  return parts.join(' · ');
}

function maintenanceNotice(type, title, item) {
  return {
    key: buildNoticeKey(type, item.id),
    type,
    title,
    detail: maintenanceDetail(item),
    dueDate: item.dueDate,
    dueMileage: item.dueMileage,
    target: { kind: 'vehicle', id: item.vehicle.id },
  };
}

/** Mantenimientos pendientes con el indicador dado, con el mismo cálculo de la lista de Mantenimientos. */
async function loadMaintenance({ indicator, type, title }, actor) {
  const { items, total } = await maintenanceService.list(
    { status: 'PENDIENTE', indicator, page: 1, pageSize: SCAN_LIMIT },
    actor,
  );
  return { total, notices: items.map((item) => maintenanceNotice(type, title, item)) };
}

/** Cargador de cada tipo de aviso. Las historias siguientes registran aquí los suyos. */
const LOADERS = {
  [NOTICE_TYPES.MAINT_OVERDUE]: (actor) =>
    loadMaintenance({ indicator: 'VENCIDO', type: NOTICE_TYPES.MAINT_OVERDUE, title: 'Mantenimiento vencido' }, actor),
};

/** Arma un grupo con la marca de lectura: lista como máximo 50 avisos y cuenta los no leídos de todos. */
function buildGroup(type, { total, notices }, readKeys) {
  const withRead = notices.map((notice) => ({ ...notice, read: readKeys.has(notice.key) }));
  const readCount = withRead.filter((notice) => notice.read).length;
  return {
    type,
    total,
    unread: Math.max(0, total - readCount),
    items: withRead.slice(0, LIST_LIMIT),
  };
}

/**
 * Avisos del usuario en este momento. El servidor decide los tipos según el rol vigente (FR-004): para los
 * tipos que el rol no puede ver NO se ejecuta ninguna consulta.
 */
export async function list(actor) {
  const allowed = new Set(typesForRole(actor.role));
  const types = GROUP_ORDER.filter((type) => allowed.has(type) && LOADERS[type]);

  const [readKeys, loaded] = await Promise.all([
    notificationReadModel.listReadKeys(actor.id),
    Promise.all(types.map((type) => LOADERS[type](actor))),
  ]);

  const groups = types
    .map((type, index) => buildGroup(type, loaded[index], readKeys))
    .filter((group) => group.total > 0);

  return {
    unread: groups.reduce((sum, group) => sum + group.unread, 0),
    total: groups.reduce((sum, group) => sum + group.total, 0),
    generatedAt: new Date().toISOString(),
    groups,
  };
}
