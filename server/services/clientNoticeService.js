import { getMaintenanceConfig } from '../config/env.js';
import * as clientNoticeModel from '../models/clientNoticeModel.js';
import * as maintenanceModel from '../models/maintenanceModel.js';
import * as noticeModel from '../models/noticeModel.js';
import { AppError } from '../utils/AppError.js';
import { formatFolio } from '../utils/orderFolio.js';
import { toDateOnly } from './maintenancePresenter.js';
import * as maintenanceService from './maintenanceService.js';
import { computeIndicator } from './maintenanceStatus.js';
import { CLIENT_NOTICE_REASONS } from './noticeRules.js';

/** Máximo de filas que devuelve la lista; el total real va en `meta.total`. */
const LIST_LIMIT = 200;

/** Máximo de mantenimientos que se revisan por indicador. */
const SCAN_LIMIT = 1000;

/** Orden de los motivos en la lista. */
const REASON_ORDER = [
  CLIENT_NOTICE_REASONS.ORDER_READY,
  CLIENT_NOTICE_REASONS.APPT_TOMORROW,
  CLIENT_NOTICE_REASONS.MAINT_OVERDUE,
  CLIENT_NOTICE_REASONS.MAINT_UPCOMING,
];

const pad = (n) => String(n).padStart(2, '0');
const formatTime = (date) => `${pad(date.getHours())}:${pad(date.getMinutes())}`;
const toLocalDate = (date) => (date ? `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` : null);

function tomorrow(now = new Date()) {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
}

const noticeKey = (reason, factId) => `${reason}:${factId}`;

/** Fila de la lista a partir de un mantenimiento (con su cliente, vehículo y fecha objetivo). */
function maintenanceRow(reason, item) {
  return {
    reason,
    factId: item.id,
    factDate: item.dueDate,
    description: item.description,
    client: item.client,
    vehicle: {
      id: item.vehicle.id,
      brand: item.vehicle.brand,
      model: item.vehicle.model,
      licensePlate: item.vehicle.licensePlate,
    },
  };
}

/** Todos los hechos que hoy cumplen un motivo, sin descartar los ya avisados. */
async function loadCandidates(actor) {
  const maintenance = (indicator) =>
    maintenanceService.list({ status: 'PENDIENTE', indicator, page: 1, pageSize: SCAN_LIMIT }, actor);

  const [orders, appointments, overdue, upcoming] = await Promise.all([
    noticeModel.listFinishedOrders(),
    noticeModel.listAppointmentsOn(tomorrow()),
    maintenance('VENCIDO'),
    maintenance('PROXIMO'),
  ]);

  return [
    ...orders.map((order) => ({
      reason: CLIENT_NOTICE_REASONS.ORDER_READY,
      factId: order.id,
      factDate: toLocalDate(order.finishedAt),
      folio: formatFolio(order.id),
      description: 'Orden terminada, lista para entregar',
      client: order.client,
      vehicle: order.vehicle,
    })),
    ...appointments.map((appointment) => ({
      reason: CLIENT_NOTICE_REASONS.APPT_TOMORROW,
      factId: appointment.id,
      factDate: toLocalDate(appointment.scheduledAt),
      description: `Cita de mañana a las ${formatTime(appointment.scheduledAt)}`,
      client: appointment.client,
      vehicle: appointment.vehicle,
    })),
    ...overdue.items.map((item) => maintenanceRow(CLIENT_NOTICE_REASONS.MAINT_OVERDUE, item)),
    ...upcoming.items.map((item) => maintenanceRow(CLIENT_NOTICE_REASONS.MAINT_UPCOMING, item)),
  ];
}

/**
 * Clientes por avisar: los hechos que cumplen un motivo y que la recepción todavía no ha avisado. Se calcula al
 * consultar; lo único que se guarda es el aviso ya hecho. Devuelve `{ items, total }`.
 */
export async function listPending(actor) {
  const [candidates, noticed] = await Promise.all([loadCandidates(actor), clientNoticeModel.listNoticedFacts()]);

  const pending = candidates
    .filter((row) => !noticed.has(noticeKey(row.reason, row.factId)))
    .sort((a, b) => {
      const byReason = REASON_ORDER.indexOf(a.reason) - REASON_ORDER.indexOf(b.reason);
      if (byReason !== 0) return byReason;
      // Sin fecha (mantenimiento solo por kilometraje) al final de su motivo.
      return (a.factDate ?? '9999-12-31').localeCompare(b.factDate ?? '9999-12-31') || a.factId - b.factId;
    });

  return {
    items: pending.slice(0, LIST_LIMIT).map((row) => ({
      reason: row.reason,
      factId: row.factId,
      factDate: row.factDate,
      ...(row.folio ? { folio: row.folio } : {}),
      description: row.description,
      client: { id: row.client.id, name: row.client.name, phone: row.client.phone ?? '' },
      vehicle: row.vehicle,
    })),
    total: pending.length,
  };
}

const notFound = () => AppError.notFound('El hecho que quieres avisar no existe.');
const notApplicable = (message) => AppError.conflict('NOTICE_NOT_APPLICABLE', message);

/**
 * Comprueba que el hecho existe y cumple hoy su motivo. Devuelve el identificador del cliente, o `null` si el
 * hecho existe pero ya no cumple el motivo (la decisión de rechazar o no la toma quien llama).
 */
async function resolveFact(reason, factId) {
  if (reason === CLIENT_NOTICE_REASONS.ORDER_READY) {
    const order = await noticeModel.findOrderFact(factId);
    if (!order) throw notFound();
    return { clientId: order.clientId, applies: order.status === 'TERMINADO', message: 'La orden ya no está lista para avisar: se entregó o cambió de estado.' };
  }

  if (reason === CLIENT_NOTICE_REASONS.APPT_TOMORROW) {
    const appointment = await noticeModel.findAppointmentFact(factId);
    if (!appointment) throw notFound();
    const isTomorrow = toLocalDate(appointment.scheduledAt) === toLocalDate(tomorrow());
    const active = ['PENDIENTE', 'CONFIRMADA'].includes(appointment.status);
    return { clientId: appointment.clientId, applies: isTomorrow && active, message: 'La cita ya no es de mañana o fue cancelada o atendida.' };
  }

  const maintenance = await maintenanceModel.findById(factId);
  if (!maintenance) throw notFound();
  const { warnDays, warnKm } = getMaintenanceConfig();
  const indicator =
    maintenance.status === 'PENDIENTE'
      ? computeIndicator({
          dueDate: toDateOnly(maintenance.dueDate),
          dueMileage: maintenance.dueMileage,
          currentMileage: maintenance.vehicle.currentMileage,
          today: new Date(),
          warnDays,
          warnKm,
        })
      : null;
  const expected = reason === CLIENT_NOTICE_REASONS.MAINT_OVERDUE ? 'VENCIDO' : 'PROXIMO';
  return {
    clientId: maintenance.client.id,
    applies: indicator === expected,
    message: 'El mantenimiento ya no está en ese estado: se atendió o cambió su fecha o kilometraje.',
  };
}

const present = (notice) => ({
  id: notice.id,
  reason: notice.reason,
  factId: notice.factId,
  clientId: notice.clientId,
  notifiedBy: notice.notifiedBy,
  notifiedAt: notice.notifiedAt instanceof Date ? notice.notifiedAt.toISOString() : notice.notifiedAt,
});

/**
 * Registra que la recepción avisó al cliente de un hecho. Es idempotente: si ya estaba avisado (por ejemplo,
 * otra persona lo marcó un instante antes) devuelve el registro existente. El sistema NO envía ningún mensaje.
 * Devuelve `{ created, notice }`.
 */
export async function register({ reason, factId }, actor) {
  const fact = await resolveFact(reason, factId);

  const existing = await clientNoticeModel.findByFact(reason, factId);
  if (existing) return { created: false, notice: present(existing) };

  if (!fact.applies) throw notApplicable(fact.message);

  const inserted = await clientNoticeModel.insertIgnore({
    clientId: fact.clientId,
    reason,
    factId,
    notifiedBy: actor.id,
  });
  const notice = await clientNoticeModel.findByFact(reason, factId);
  return { created: inserted, notice: present(notice) };
}
