import { z } from 'zod';
import { listQuery, optionalText, requiredText } from './common.js';
import { isoDateTime } from './orderCommon.js';

export const APPOINTMENT_STATUSES = ['PENDIENTE', 'CONFIRMADA', 'EN_PROCESO', 'COMPLETADA', 'CANCELADA'];

const positiveId = (label) =>
  z
    .number({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} no es válido.` })
    .int(`${label} no es válido.`)
    .positive(`${label} no es válido.`);

const reason = requiredText('El motivo', 255);
const notes = optionalText('Las observaciones', 1000);

export const createAppointmentSchema = z.object({
  clientId: positiveId('El cliente'),
  vehicleId: positiveId('El vehículo'),
  scheduledAt: isoDateTime('La fecha y hora'),
  reason,
  notes,
});

/** Edición parcial: el cliente y el vehículo no cambian. Debe enviarse al menos un campo. */
export const updateAppointmentSchema = z
  .object({
    scheduledAt: isoDateTime('La fecha y hora').optional(),
    reason: reason.optional(),
    notes,
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

export const cancelAppointmentSchema = z.object({
  reason: optionalText('El motivo de la cancelación', 255),
});

export const listAppointmentsQuery = listQuery.extend({
  status: z.enum(APPOINTMENT_STATUSES, { message: 'El estado no es válido.' }).optional(),
  from: isoDateTime('La fecha inicial').optional(),
  to: isoDateTime('La fecha final').optional(),
});
