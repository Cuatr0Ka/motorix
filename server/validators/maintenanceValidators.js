import { z } from 'zod';
import { listQuery } from './common.js';

const description = z
  .string({ required_error: 'La descripción es obligatoria.', invalid_type_error: 'La descripción es obligatoria.' })
  .trim()
  .min(3, 'La descripción debe tener al menos 3 caracteres.')
  .max(255, 'La descripción no puede pasar de 255 caracteres.');

/** Fecha sin hora `YYYY-MM-DD` válida; vacío o null → null. */
const dueDate = z.preprocess(
  (value) => (typeof value === 'string' ? value.trim() || null : value),
  z
    .string({ invalid_type_error: 'La fecha no es válida.' })
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'La fecha debe tener el formato AAAA-MM-DD.')
    .refine((value) => {
      const date = new Date(`${value}T00:00:00Z`);
      return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
    }, 'La fecha no es válida.')
    .nullable()
    .optional(),
);

const dueMileage = z
  .number({ invalid_type_error: 'El kilometraje debe ser un número.' })
  .int('El kilometraje debe ser un número entero.')
  .min(0, 'El kilometraje no puede ser negativo.')
  .max(2000000, 'El kilometraje no puede pasar de 2 000 000.')
  .nullable()
  .optional();

/** Alta: descripción obligatoria; la regla «al menos fecha o kilometraje» la aplica el servicio. */
export const createMaintenanceSchema = z.object({ description, dueDate, dueMileage });

export const updateMaintenanceSchema = z
  .object({ description: description.optional(), dueDate, dueMileage })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

export const listMaintenanceQuery = listQuery.extend({
  status: z.enum(['PENDIENTE', 'ATENDIDO'], { message: 'El estado no es válido.' }).default('PENDIENTE'),
  indicator: z.enum(['NORMAL', 'PROXIMO', 'VENCIDO'], { message: 'El indicador no es válido.' }).optional(),
});
