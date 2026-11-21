import { z } from 'zod';

const name = z
  .string({ required_error: 'El nombre es obligatorio.', invalid_type_error: 'El nombre no es válido.' })
  .trim()
  .min(1, 'El nombre es obligatorio.')
  .max(100, 'El nombre no puede pasar de 100 caracteres.');

const intervalDays = z
  .number({ invalid_type_error: 'El intervalo en días debe ser un número.' })
  .int('El intervalo en días debe ser un número entero.')
  .min(1, 'El intervalo en días debe estar entre 1 y 3 650.')
  .max(3650, 'El intervalo en días debe estar entre 1 y 3 650.')
  .nullable();

const intervalKm = z
  .number({ invalid_type_error: 'El intervalo en kilómetros debe ser un número.' })
  .int('El intervalo en kilómetros debe ser un número entero.')
  .min(1, 'El intervalo en kilómetros debe estar entre 1 y 1 000 000.')
  .max(1000000, 'El intervalo en kilómetros debe estar entre 1 y 1 000 000.')
  .nullable();

/** Alta: nombre y al menos un intervalo (la regla de «al menos uno» responde 422 en el servicio). */
export const createServiceTypeSchema = z
  .object({ name, intervalDays: intervalDays.optional(), intervalKm: intervalKm.optional() })
  .strict('Hay campos que no se pueden enviar.');

/** Edición parcial: nombre, intervalos (null los quita) y estado. */
export const updateServiceTypeSchema = z
  .object({
    name: name.optional(),
    intervalDays: intervalDays.optional(),
    intervalKm: intervalKm.optional(),
    active: z.boolean({ invalid_type_error: 'El estado no es válido.' }).optional(),
  })
  .strict('Hay campos que no se pueden enviar.')
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

export const listServiceTypesQuery = z.object({
  active: z.enum(['true', 'false'], { invalid_type_error: 'El filtro de estado no es válido.' }).transform((v) => v === 'true').optional(),
});
