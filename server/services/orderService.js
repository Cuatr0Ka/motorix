import { withTransaction } from '../config/db.js';
import * as appointmentModel from '../models/appointmentModel.js';
import * as maintenanceModel from '../models/maintenanceModel.js';
import * as orderModel from '../models/orderModel.js';
import * as orderPartModel from '../models/orderPartModel.js';
import * as orderWorkModel from '../models/orderWorkModel.js';
import * as userModel from '../models/userModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';
import { presentMaintenance } from './maintenancePresenter.js';
import { getBilling } from './paymentService.js';
import { assertEntryMileage } from './mileageRule.js';
import { ORDER_STATUS_LABELS, allowedFor, assertTransition, canActorTransition } from './orderTransitions.js';

const AVAILABLE_APPOINTMENT_STATUSES = ['PENDIENTE', 'CONFIRMADA'];

const vehicleNotFound = () =>
  AppError.unprocessable('VEHICLE_NOT_FOUND', 'El vehículo seleccionado no existe. Elige un vehículo registrado.');
const mechanicInvalid = () =>
  AppError.unprocessable('MECHANIC_INVALID', 'El mecánico seleccionado no existe, está inactivo o no tiene el rol de mecánico.');
const appointmentUnavailable = () =>
  AppError.conflict(
    'APPOINTMENT_NOT_AVAILABLE',
    'La cita no está disponible para crear una orden: debe estar Pendiente o Confirmada y no tener una orden.',
  );
const orderNotFound = () => AppError.notFound('La orden no existe.');

async function openOrderExists(vehicleId) {
  const ref = await orderModel.findOpenOrderRef(vehicleId);
  return AppError.conflict(
    'OPEN_ORDER_EXISTS',
    ref
      ? `El vehículo ya tiene una orden abierta (${ref.folio}). Debe entregarse antes de crear otra.`
      : 'El vehículo ya tiene una orden abierta. Debe entregarse antes de crear otra.',
    ref ?? undefined,
  );
}

/** Traduce los errores de clave duplicada (condiciones de carrera) a los errores de negocio. */
async function translateDbError(error, vehicleId) {
  if (error?.code === 'ER_DUP_ENTRY') {
    return String(error.message).includes('uq_orders_appointment') ? appointmentUnavailable() : openOrderExists(vehicleId);
  }
  return error;
}

/** Resumen de la orden para los listados. */
export function toSummary(order) {
  return {
    id: order.id,
    folio: order.folio,
    status: order.status,
    reportedProblem: order.reportedProblem,
    entryMileage: order.entryMileage,
    createdAt: order.createdAt,
    client: order.client,
    vehicle: order.vehicle,
    mechanic: order.mechanic,
  };
}

/** Detalle de la orden: resumen + trabajo, totales, historial y transiciones que puede ejecutar quien consulta. */
export async function buildDetail(order, actor, connection) {
  const [services, labor, totals, statusHistory, scheduled, parts] = await Promise.all([
    orderWorkModel.listServices(order.id, connection),
    orderWorkModel.listLabor(order.id, connection),
    orderWorkModel.totals(order.id, connection),
    orderWorkModel.listHistory(order.id, connection),
    maintenanceModel.findLatestByOrder(order.id, connection),
    orderPartModel.listByOrder(order.id, connection),
  ]);
  // Una orden sin mecánico no puede salir de RECIBIDO: no se ofrece ninguna transición.
  const unassigned = order.mechanicId == null && order.status === 'RECIBIDO';
  const allowedTransitions = unassigned ? [] : allowedFor({ role: actor.role, userId: actor.id, order });
  // El bloque de cobro solo lo reciben administración y recepción (el mecánico no accede a los pagos).
  const billing = actor.role === 'MECHANIC' ? undefined : await getBilling(order, connection);
  return {
    ...toSummary(order),
    diagnosis: order.diagnosis,
    observations: order.observations,
    recommendations: order.recommendations,
    serviceMileage: order.serviceMileage,
    maintenance: scheduled ? presentMaintenance(scheduled, scheduled.currentMileage) : null,
    mileageCorrection: order.mileageCorrection,
    mileageCorrectionReason: order.mileageCorrectionReason,
    appointment: order.appointment,
    services,
    labor,
    parts,
    totals,
    allowedTransitions,
    statusHistory,
    deliveredAt: order.deliveredAt,
    ...(billing ? { billing } : {}),
  };
}

/**
 * Carga la orden para quien actúa. Un mecánico solo accede a las suyas: una orden ajena responde igual
 * que una inexistente (404) para no revelar sus datos.
 */
export async function loadOrderForActor(id, actor, connection) {
  const order = await orderModel.findById(id, connection);
  if (!order) throw orderNotFound();
  if (actor.role === 'MECHANIC' && order.mechanicId !== actor.id) throw orderNotFound();
  return order;
}

/** Listado. El mecánico solo ve las suyas y, por defecto, sin las entregadas. */
export async function list(filters, actor) {
  const scoped = { ...filters };
  if (actor.role === 'MECHANIC') {
    scoped.mechanicId = actor.id;
    if (!scoped.status) scoped.excludeStatus = 'ENTREGADO';
  }
  const { items, total } = await orderModel.list(scoped);
  return { items: items.map(toSummary), total };
}

export async function getById(id, actor) {
  return buildDetail(await loadOrderForActor(id, actor), actor);
}

/**
 * Crea una orden, directa o desde una cita, en una transacción: valida el vehículo, el mecánico y el
 * kilometraje de entrada, impide una segunda orden abierta, registra la entrada inicial del historial,
 * actualiza el kilometraje del vehículo y pasa la cita (si hay) a EN_PROCESO.
 */
export async function create(data, actor) {
  let vehicleIdForErrors = data.vehicleId;
  let orderId;
  try {
    orderId = await withTransaction(async (connection) => {
      let vehicleId = data.vehicleId;
      let reportedProblem = data.reportedProblem;
      let appointment = null;

      if (data.appointmentId) {
        appointment = await appointmentModel.lockById(data.appointmentId, connection);
        if (!appointment) throw AppError.notFound('La cita no existe.');
        if (!AVAILABLE_APPOINTMENT_STATUSES.includes(appointment.status)) throw appointmentUnavailable();
        vehicleId = appointment.vehicle_id;
        reportedProblem = reportedProblem ?? appointment.reason;
      }
      vehicleIdForErrors = vehicleId;

      const vehicle = await vehicleModel.lockForUpdate(vehicleId, connection);
      if (!vehicle) throw vehicleNotFound();

      if (data.mechanicId != null && !(await userModel.findActiveMechanic(data.mechanicId, connection))) {
        throw mechanicInvalid();
      }

      const { correctionApplied, reason } = assertEntryMileage({
        previous: vehicle.current_mileage,
        entry: data.entryMileage,
        correction: data.mileageCorrection,
        reason: data.mileageCorrectionReason,
      });

      if (await orderModel.findOpenByVehicle(vehicleId, connection)) throw await openOrderExists(vehicleId);

      const id = await orderModel.create(
        {
          clientId: vehicle.client_id,
          vehicleId,
          appointmentId: appointment?.id ?? null,
          mechanicId: data.mechanicId ?? null,
          reportedProblem,
          entryMileage: data.entryMileage,
          mileageCorrection: correctionApplied,
          mileageCorrectionReason: reason,
          createdBy: actor.id,
        },
        connection,
      );
      await orderWorkModel.insertHistory({ orderId: id, fromStatus: null, toStatus: 'RECIBIDO', changedBy: actor.id }, connection);
      await vehicleModel.setMileage(vehicleId, data.entryMileage, connection);
      if (appointment) {
        const changed = await appointmentModel.setStatusIf(
          appointment.id,
          AVAILABLE_APPOINTMENT_STATUSES,
          'EN_PROCESO',
          {},
          connection,
        );
        if (!changed) throw appointmentUnavailable();
      }
      return id;
    });
  } catch (error) {
    throw await translateDbError(error, vehicleIdForErrors);
  }
  return getById(orderId, actor);
}

/**
 * Asigna o reasigna el mecánico de una orden (recepción y administración). No se permite en órdenes
 * Terminadas ni Entregadas, y solo se quita la asignación (null) mientras la orden siga Recibida.
 */
export async function assignMechanic(id, mechanicId, actor) {
  await withTransaction(async (connection) => {
    const order = await orderModel.lockById(id, connection);
    if (!order) throw orderNotFound();

    if (order.status === 'ENTREGADO') {
      throw AppError.conflict('ORDER_READ_ONLY', 'La orden está entregada: es de solo lectura y no admite cambios.');
    }
    if (order.status === 'TERMINADO') {
      throw AppError.conflict('ORDER_NOT_ASSIGNABLE', 'No se puede asignar un mecánico a una orden Terminada.');
    }
    if (mechanicId === null) {
      if (order.status !== 'RECIBIDO') {
        throw AppError.conflict('ORDER_NOT_ASSIGNABLE', 'Solo se puede quitar la asignación mientras la orden esté Recibida.');
      }
    } else if (!(await userModel.findActiveMechanic(mechanicId, connection))) {
      throw mechanicInvalid();
    }
    await orderModel.setMechanic(id, mechanicId, connection);
  });
  return getById(id, actor);
}

/**
 * Cambia el estado de una orden (US6). Orden de las comprobaciones: la orden es del mecánico (404 si no),
 * no está entregada (409), el rol puede hacer ese cambio (403), la transición es válida (422), tiene
 * mecánico para salir de RECIBIDO (422) y nadie la cambió mientras tanto (409 STATE_CONFLICT). El cambio,
 * el historial y la sincronización de la cita ocurren en una sola transacción.
 */
export async function changeStatus(id, to, actor) {
  const order = await loadOrderForActor(id, actor);

  if (order.status === 'ENTREGADO') {
    throw AppError.conflict('ORDER_READ_ONLY', 'La orden está entregada: es de solo lectura y no admite cambios.');
  }
  if (!canActorTransition({ role: actor.role, userId: actor.id, order, to })) {
    throw AppError.forbidden(
      to === 'ENTREGADO'
        ? 'Solo recepción o administración pueden registrar la entrega de una orden.'
        : 'Solo el mecánico asignado o el administrador pueden cambiar el estado de esta orden.',
    );
  }
  assertTransition(order.status, to);
  if (order.status === 'RECIBIDO' && order.mechanicId == null) {
    throw AppError.unprocessable(
      'ORDER_UNASSIGNED',
      'Asigna un mecánico a la orden antes de iniciar el trabajo.',
      { currentStatus: order.status },
    );
  }

  await withTransaction(async (connection) => {
    const changed = await orderModel.updateStatusIf(id, order.status, to, connection);
    if (!changed) {
      const currentStatus = await orderModel.currentStatus(id, connection);
      throw AppError.conflict(
        'STATE_CONFLICT',
        `El estado de la orden cambió mientras la revisabas. Ahora está en ${ORDER_STATUS_LABELS[currentStatus] ?? currentStatus}. Revisa la orden e inténtalo de nuevo.`,
        { currentStatus },
      );
    }
    await orderWorkModel.insertHistory({ orderId: id, fromStatus: order.status, toStatus: to, changedBy: actor.id }, connection);
    if (to === 'TERMINADO' && order.appointment) {
      await appointmentModel.setStatusIf(order.appointment.id, ['EN_PROCESO'], 'COMPLETADA', {}, connection);
    }
  });
  return getById(id, actor);
}
