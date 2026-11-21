import * as noticeModel from '../models/noticeModel.js';
import * as notificationReadModel from '../models/notificationReadModel.js';
import * as maintenanceService from './maintenanceService.js';
import * as partService from './partService.js';
import { formatFolio } from '../utils/orderFolio.js';
import { GROUP_ORDER, NOTICE_TYPES, buildNoticeKey, daysSince, isStalledOrder, typesForRole } from './noticeRules.js';

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

/**
 * Refacciones activas con stock bajo (en o bajo su mínimo) o agotado, con el mismo cálculo de las alertas del
 * inventario y del panel de control. Solo se ejecuta para el administrador.
 */
async function loadStock(type, title) {
  const alerts = await partService.alerts();
  const wanted = type === NOTICE_TYPES.STOCK_OUT ? 'AGOTADO' : 'BAJO';
  const notices = alerts.items
    .filter((part) => part.stockStatus === wanted)
    .map((part) => ({
      key: buildNoticeKey(type, part.id),
      type,
      title,
      detail: `${part.name} · ${part.code}`,
      stock: part.stock,
      minStock: part.minStock,
      target: { kind: 'part', id: part.id },
    }));
  return { total: notices.length, notices };
}

const ORDER_STATUS_LABELS = {
  RECIBIDO: 'Recibida',
  DIAGNOSTICO: 'Diagnóstico',
  EN_REPARACION: 'En reparación',
  ESPERANDO_REFACCION: 'Esperando refacción',
};

/**
 * Órdenes abiertas con más de 3 días sin cambio de estado (D-01). El mecánico solo recibe las órdenes que tiene
 * asignadas y sin el nombre del cliente; administración y recepción reciben todas. La más detenida va primero.
 */
async function loadStalledOrders(actor) {
  const isMechanic = actor.role === 'MECHANIC';
  const orders = await noticeModel.listOpenOrdersWithLastChange(isMechanic ? { mechanicId: actor.id } : {});
  const today = new Date();

  const stalled = orders
    .map((order) => ({ order, lastChangeAt: order.lastChangeAt ?? order.createdAt }))
    .filter(({ order, lastChangeAt }) => isStalledOrder({ status: order.status, lastChangeAt, today }))
    .map(({ order, lastChangeAt }) => ({ order, days: daysSince(lastChangeAt, today) }))
    .sort((a, b) => b.days - a.days || a.order.id - b.order.id);

  const notices = stalled.map(({ order, days }) => {
    const folio = formatFolio(order.id);
    const vehicle = `${order.vehicle.brand} ${order.vehicle.model} ${order.vehicle.licensePlate}`;
    const parts = [folio, vehicle];
    if (!isMechanic) parts.push(order.client.name);
    parts.push(ORDER_STATUS_LABELS[order.status] ?? order.status, `${days} días sin cambio`);
    return {
      key: buildNoticeKey(NOTICE_TYPES.STALLED, order.id, order.lastHistoryId),
      type: NOTICE_TYPES.STALLED,
      title: 'Orden detenida',
      detail: parts.join(' · '),
      folio,
      status: order.status,
      daysStalled: days,
      target: { kind: 'order', id: order.id },
    };
  });
  return { total: notices.length, notices };
}

/** Cargador de cada tipo de aviso. Las historias siguientes registran aquí los suyos. */
const LOADERS = {
  [NOTICE_TYPES.MAINT_OVERDUE]: (actor) =>
    loadMaintenance({ indicator: 'VENCIDO', type: NOTICE_TYPES.MAINT_OVERDUE, title: 'Mantenimiento vencido' }, actor),
  [NOTICE_TYPES.MAINT_UPCOMING]: (actor) =>
    loadMaintenance({ indicator: 'PROXIMO', type: NOTICE_TYPES.MAINT_UPCOMING, title: 'Mantenimiento próximo' }, actor),
  [NOTICE_TYPES.APPT_TODAY]: () => loadAppointmentsToday(),
  [NOTICE_TYPES.STALLED]: (actor) => loadStalledOrders(actor),
  [NOTICE_TYPES.STOCK_OUT]: () => loadStock(NOTICE_TYPES.STOCK_OUT, 'Stock agotado'),
  [NOTICE_TYPES.STOCK_LOW]: () => loadStock(NOTICE_TYPES.STOCK_LOW, 'Stock bajo'),
};

/** Campos que puede traer un aviso para el mecánico: nunca nombre de cliente ni teléfono. */
const MECHANIC_FIELDS = ['key', 'type', 'read', 'title', 'detail', 'folio', 'status', 'daysStalled', 'target'];

/**
 * Defensa en profundidad (FR-004, FR-015): aunque un cargador agregara por error datos del cliente, el aviso del
 * mecánico solo conserva los campos de `MECHANIC_FIELDS`.
 */
export function projectForRole(notice, role) {
  if (role !== 'MECHANIC') return notice;
  return Object.fromEntries(Object.entries(notice).filter(([field]) => MECHANIC_FIELDS.includes(field)));
}

/** Arma un grupo con la marca de lectura: lista como máximo 50 avisos y cuenta los no leídos de todos. */
function buildGroup(type, { total, notices }, readKeys, role) {
  const withRead = notices.map((notice) => projectForRole({ ...notice, read: readKeys.has(notice.key) }, role));
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
function summarize(loaded, readKeys, role) {
  const allowed = new Set(typesForRole(role));
  const groups = loaded
    .filter(({ type }) => allowed.has(type))
    .map(({ type, total, notices }) => buildGroup(type, { total, notices }, readKeys, role))
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
  return summarize(loaded, readKeys, actor.role);
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
  return { marked: valid.length, unread: summarize(loaded, readKeys, actor.role).unread };
}
