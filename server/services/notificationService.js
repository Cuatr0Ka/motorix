import * as noticeModel from '../models/noticeModel.js';
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

/** Hora de una cita como «HH:mm» (hora local del servidor). */
const formatTime = (date) => `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;

/** Citas de hoy que siguen vigentes (pendientes o confirmadas), por hora. Muestran la hora, el motivo y el cliente. */
async function loadAppointmentsToday() {
  const rows = await noticeModel.listAppointmentsOn(new Date());
  const notices = rows.map((row) => ({
    key: buildNoticeKey(NOTICE_TYPES.APPT_TODAY, row.id),
    type: NOTICE_TYPES.APPT_TODAY,
    title: 'Cita de hoy',
    detail: [
      formatTime(row.scheduledAt),
      row.reason,
      `${row.vehicle.brand} ${row.vehicle.model} ${row.vehicle.licensePlate}`,
      row.client.name,
    ].join(' · '),
    scheduledAt: row.scheduledAt.toISOString(),
    target: { kind: 'appointment', id: row.id },
  }));
  return { total: notices.length, notices };
}

/** Cargador de cada tipo de aviso. Las historias siguientes registran aquí los suyos. */
const LOADERS = {
  [NOTICE_TYPES.MAINT_OVERDUE]: (actor) =>
    loadMaintenance({ indicator: 'VENCIDO', type: NOTICE_TYPES.MAINT_OVERDUE, title: 'Mantenimiento vencido' }, actor),
  [NOTICE_TYPES.MAINT_UPCOMING]: (actor) =>
    loadMaintenance({ indicator: 'PROXIMO', type: NOTICE_TYPES.MAINT_UPCOMING, title: 'Mantenimiento próximo' }, actor),
  [NOTICE_TYPES.APPT_TODAY]: () => loadAppointmentsToday(),
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
 * Carga los avisos que el rol del usuario puede ver. El servidor decide los tipos según el rol vigente (FR-004):
 * para los tipos que el rol no puede ver NO se ejecuta ninguna consulta.
 */
async function loadForActor(actor) {
  const allowed = new Set(typesForRole(actor.role));
  const types = GROUP_ORDER.filter((type) => allowed.has(type) && LOADERS[type]);
  const loaded = await Promise.all(types.map((type) => LOADERS[type](actor)));
  return types.map((type, index) => ({ type, ...loaded[index] }));
}

/** Resumen listo para la API a partir de los avisos cargados y de las claves que el usuario ya leyó. */
function summarize(loaded, readKeys) {
  const groups = loaded
    .map(({ type, total, notices }) => buildGroup(type, { total, notices }, readKeys))
    .filter((group) => group.total > 0);

  return {
    unread: groups.reduce((sum, group) => sum + group.unread, 0),
    total: groups.reduce((sum, group) => sum + group.total, 0),
    generatedAt: new Date().toISOString(),
    groups,
  };
}

/** Avisos del usuario en este momento. */
export async function list(actor) {
  const [readKeys, loaded] = await Promise.all([notificationReadModel.listReadKeys(actor.id), loadForActor(actor)]);
  return summarize(loaded, readKeys);
}

/**
 * Marca avisos como leídos para el usuario. Solo se registran las claves que correspondan a avisos vigentes que
 * el rol puede ver; las demás (un aviso que desapareció mientras el panel estaba abierto, o uno ajeno al rol)
 * se ignoran sin error. Repetir o hacer la misma solicitud en paralelo no duplica ni falla (FR-021).
 */
export async function markRead(keys, actor) {
  const loaded = await loadForActor(actor);
  const current = new Set(loaded.flatMap(({ notices }) => notices.map((notice) => notice.key)));
  const valid = [...new Set(keys)].filter((key) => current.has(key));

  await notificationReadModel.insertIgnore(actor.id, valid);

  const readKeys = await notificationReadModel.listReadKeys(actor.id);
  return { marked: valid.length, unread: summarize(loaded, readKeys).unread };
}
