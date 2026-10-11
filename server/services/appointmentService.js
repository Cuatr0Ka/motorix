import * as appointmentModel from '../models/appointmentModel.js';
import * as clientModel from '../models/clientModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';

const PAST_TOLERANCE_MS = 60 * 1000;
const EDITABLE = ['PENDIENTE', 'CONFIRMADA'];

const slotTaken = () =>
  AppError.conflict('APPOINTMENT_SLOT_TAKEN', 'Ese vehículo ya tiene una cita activa en esa fecha y hora.');
const notEditable = () =>
  AppError.conflict(
    'APPOINTMENT_NOT_EDITABLE',
    'Solo se pueden modificar, confirmar o cancelar citas Pendientes o Confirmadas.',
  );

/** Traduce el error de clave duplicada del horario (condición de carrera) al error de negocio. */
function translateDbError(error) {
  if (error?.code === 'ER_DUP_ENTRY') return slotTaken();
  return error;
}

function assertNotInPast(scheduledAt) {
  if (scheduledAt.getTime() < Date.now() - PAST_TOLERANCE_MS) {
    throw AppError.unprocessable(
      'APPOINTMENT_IN_PAST',
      'La fecha y hora de la cita no pueden ser anteriores al momento actual.',
    );
  }
}

export async function list(filters) {
  return appointmentModel.list(filters);
}

export async function getById(id) {
  const appointment = await appointmentModel.findById(id);
  if (!appointment) throw AppError.notFound('La cita no existe.');
  return appointment;
}

/** Registra una cita en estado PENDIENTE para un vehículo del cliente indicado. */
export async function create(data, actor) {
  if (!(await clientModel.exists(data.clientId))) {
    throw AppError.unprocessable('VEHICLE_NOT_FOUND', 'El cliente seleccionado no existe. Elige un cliente registrado.');
  }
  const vehicle = await vehicleModel.findById(data.vehicleId);
  if (!vehicle) {
    throw AppError.unprocessable('VEHICLE_NOT_FOUND', 'El vehículo seleccionado no existe. Elige un vehículo registrado.');
  }
  if (vehicle.client.id !== data.clientId) {
    throw AppError.unprocessable('VEHICLE_CLIENT_MISMATCH', 'El vehículo seleccionado no pertenece a ese cliente.');
  }
  assertNotInPast(data.scheduledAt);
  if (await appointmentModel.findActiveSlot(data.vehicleId, data.scheduledAt)) throw slotTaken();

  try {
    const id = await appointmentModel.create({ ...data, createdBy: actor.id });
    return await appointmentModel.findById(id);
  } catch (error) {
    throw translateDbError(error);
  }
}

/** Modifica fecha, motivo u observaciones mientras la cita siga Pendiente o Confirmada. */
export async function update(id, data) {
  const current = await getById(id);
  if (!EDITABLE.includes(current.status)) throw notEditable();

  if (data.scheduledAt && data.scheduledAt.getTime() !== new Date(current.scheduledAt).getTime()) {
    assertNotInPast(data.scheduledAt);
    if (await appointmentModel.findActiveSlot(current.vehicle.id, data.scheduledAt, id)) throw slotTaken();
  }

  try {
    await appointmentModel.update(id, data);
    return await appointmentModel.findById(id);
  } catch (error) {
    throw translateDbError(error);
  }
}

/** PENDIENTE → CONFIRMADA (acción manual de recepción o administración). */
export async function confirm(id) {
  await getById(id);
  if (!(await appointmentModel.setStatusIf(id, ['PENDIENTE'], 'CONFIRMADA'))) throw notEditable();
  return appointmentModel.findById(id);
}

/** PENDIENTE o CONFIRMADA → CANCELADA. La cita se conserva como historial. */
export async function cancel(id, { reason } = {}) {
  await getById(id);
  const changed = await appointmentModel.setStatusIf(id, EDITABLE, 'CANCELADA', {
    cancelReason: reason ?? null,
    cancelledAt: new Date(),
  });
  if (!changed) throw notEditable();
  return appointmentModel.findById(id);
}
