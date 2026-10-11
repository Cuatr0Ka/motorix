import { z } from 'zod';
import { listQuery, optionalText, requiredText } from './common.js';

/** VIN: 17 caracteres alfanuméricos sin I, O, Q. Vacío → null; siempre en mayúsculas. */
const vin = z.preprocess(
  (value) => (typeof value === 'string' ? value.trim().toUpperCase() || null : value),
  z
    .string({ invalid_type_error: 'El número de serie (VIN) no es válido.' })
    .regex(/^[A-HJ-NPR-Z0-9]{17}$/, 'El VIN debe tener 17 caracteres alfanuméricos, sin las letras I, O ni Q.')
    .nullable()
    .optional(),
);

const maxYear = () => new Date().getFullYear() + 1;

/** Año: de 1950 al año actual + 1. */
const year = z
  .number({ required_error: 'El año es obligatorio.', invalid_type_error: 'El año debe ser un número.' })
  .int('El año debe ser un número entero.')
  .min(1950, 'El año no puede ser anterior a 1950.')
  .refine((value) => value <= maxYear(), () => ({ message: `El año no puede pasar de ${maxYear()}.` }));

const clientId = z
  .number({ required_error: 'El propietario es obligatorio.', invalid_type_error: 'El propietario no es válido.' })
  .int('El propietario no es válido.')
  .positive('El propietario no es válido.');

const licensePlate = requiredText('La placa', 15).transform((value) => value.toUpperCase());

/** Kilometraje opcional: entero no negativo. */
const currentMileage = z
  .number({ invalid_type_error: 'El kilometraje debe ser un número.' })
  .int('El kilometraje debe ser un número entero.')
  .min(0, 'El kilometraje no puede ser negativo.')
  .nullable()
  .optional();

export const createVehicleSchema = z.object({
  clientId,
  brand: requiredText('La marca', 60),
  model: requiredText('El modelo', 60),
  year,
  licensePlate,
  vin,
  color: optionalText('El color', 40),
  currentMileage,
});

/**
 * Edición parcial: cualquier campo del alta, más `mileageCorrection` para permitir bajar el
 * kilometraje de forma explícita. Debe enviarse al menos un campo.
 */
export const updateVehicleSchema = createVehicleSchema
  .partial()
  .extend({ mileageCorrection: z.boolean({ invalid_type_error: 'La corrección de kilometraje no es válida.' }).optional() })
  .refine(
    (data) => Object.keys(data).some((key) => key !== 'mileageCorrection' && data[key] !== undefined),
    { message: 'Envía al menos un campo para actualizar.' },
  );

export const listVehiclesQuery = listQuery.extend({
  clientId: z.coerce
    .number({ invalid_type_error: 'El filtro de cliente no es válido.' })
    .int('El filtro de cliente no es válido.')
    .positive('El filtro de cliente no es válido.')
    .optional(),
});
