import { z } from 'zod';
import { idParams, listQuery, requiredText } from './common.js';
import { entryMileage, longText, money } from './orderCommon.js';

export const ORDER_STATUS_VALUES = ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO', 'ENTREGADO'];

const positiveId = (label) =>
  z
    .number({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} no es válido.` })
    .int(`${label} no es válido.`)
    .positive(`${label} no es válido.`);

/** Texto opcional recortado: vacío o null → undefined (se trata como "no enviado"). */
const optionalTrimmed = (label, max, min = 0) =>
  z.preprocess(
    (value) => (typeof value === 'string' ? value.trim() || undefined : value === null ? undefined : value),
    z
      .string({ invalid_type_error: `${label} no es válido.` })
      .min(min, `${label} debe tener al menos ${min} caracteres.`)
      .max(max, `${label} no puede pasar de ${max} caracteres.`)
      .optional(),
  );

/**
 * Alta de orden: directa (`vehicleId`) o desde una cita (`appointmentId`), nunca ambas.
 * El problema reportado es obligatorio salvo que se tome del motivo de la cita.
 * La corrección de kilometraje exige un motivo; la regla de negocio (comparar con el kilometraje
 * actual del vehículo) la aplica el servicio.
 */
export const createOrderSchema = z
  .object({
    vehicleId: positiveId('El vehículo').optional(),
    appointmentId: positiveId('La cita').optional(),
    entryMileage,
    reportedProblem: optionalTrimmed('El problema reportado', 1000),
    mechanicId: positiveId('El mecánico').nullable().optional(),
    mileageCorrection: z.boolean({ invalid_type_error: 'La corrección de kilometraje no es válida.' }).optional(),
    mileageCorrectionReason: optionalTrimmed('El motivo de la corrección', 255),
  })
  .superRefine((data, ctx) => {
    const hasVehicle = data.vehicleId !== undefined;
    const hasAppointment = data.appointmentId !== undefined;
    if (hasVehicle === hasAppointment) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: [hasVehicle ? 'appointmentId' : 'vehicleId'],
        message: hasVehicle ? 'Indica el vehículo o la cita de origen, no ambos.' : 'Indica el vehículo o la cita de origen.',
      });
    }
    if (!hasAppointment && data.reportedProblem === undefined) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['reportedProblem'], message: 'El problema reportado es obligatorio.' });
    }
    if (data.mileageCorrection && (data.mileageCorrectionReason ?? '').length < 5) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['mileageCorrectionReason'],
        message: 'El motivo de la corrección debe tener al menos 5 caracteres.',
      });
    }
    if (!data.mileageCorrection && data.mileageCorrectionReason !== undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['mileageCorrection'],
        message: 'Marca la corrección de kilometraje para indicar su motivo.',
      });
    }
  });

export const listOrdersQuery = listQuery.extend({
  status: z.enum(ORDER_STATUS_VALUES, { message: 'El estado no es válido.' }).optional(),
  mechanicId: z.coerce
    .number({ invalid_type_error: 'El filtro de mecánico no es válido.' })
    .int('El filtro de mecánico no es válido.')
    .positive('El filtro de mecánico no es válido.')
    .optional(),
});

/** Asignación de mecánico: un id de usuario o `null` para quitar la asignación. */
export const assignMechanicSchema = z.object({
  mechanicId: z
    .number({ required_error: 'El mecánico es obligatorio.', invalid_type_error: 'El mecánico no es válido.' })
    .int('El mecánico no es válido.')
    .positive('El mecánico no es válido.')
    .nullable(),
});

/** Trabajo de la orden: diagnóstico, observaciones y recomendaciones (texto o null; al menos un campo). */
export const updateWorkSchema = z
  .object({
    diagnosis: longText('El diagnóstico'),
    observations: longText('Las observaciones'),
    recommendations: longText('Las recomendaciones'),
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

const description = requiredText('La descripción', 255);

/** Línea de servicio realizado o de mano de obra: descripción (1 a 255) e importe (0 a 9 999 999.99). */
export const createLineSchema = z.object({
  description,
  amount: money('El importe'),
});

export const updateLineSchema = z
  .object({
    description: description.optional(),
    amount: money('El importe').optional(),
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

/** Parámetros de una línea: orden y línea (servicio o mano de obra). */
export const lineParams = idParams.extend({
  lineId: z.coerce
    .number({ invalid_type_error: 'El identificador de la línea no es válido.' })
    .int('El identificador de la línea no es válido.')
    .positive('El identificador de la línea no es válido.'),
});

/** Cambio de estado de la orden: el estado destino debe ser uno de los seis del flujo. */
export const changeStatusSchema = z.object({
  status: z.enum(ORDER_STATUS_VALUES, {
    required_error: 'El estado es obligatorio.',
    invalid_type_error: 'El estado no es válido.',
    message: 'El estado no es válido.',
  }),
});

/** Kilometraje del servicio: entero de 0 a 2 000 000 (la comparación con el de entrada la hace el servicio). */
export const serviceMileageSchema = z.object({
  serviceMileage: z
    .number({ required_error: 'El kilometraje del servicio es obligatorio.', invalid_type_error: 'El kilometraje debe ser un número.' })
    .int('El kilometraje debe ser un número entero.')
    .min(0, 'El kilometraje no puede ser negativo.')
    .max(2000000, 'El kilometraje no puede pasar de 2 000 000.'),
});

const partQuantity = z
  .number({ required_error: 'La cantidad es obligatoria.', invalid_type_error: 'La cantidad debe ser un número.' })
  .int('La cantidad debe ser un número entero.')
  .min(1, 'La cantidad debe ser al menos 1.')
  .max(100000, 'La cantidad no puede pasar de 100 000.');

/** Refacción usada en la orden: se suma a la línea existente si ya estaba. */
export const addOrderPartSchema = z.object({ partId: positiveId('La refacción'), quantity: partQuantity });

/** Corrección de una línea: cantidad nueva total. */
export const updateOrderPartSchema = z.object({ quantity: partQuantity });

/** Parámetros de una línea de refacción de la orden. */
export const orderPartParams = lineParams;
