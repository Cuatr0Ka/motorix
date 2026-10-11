import { z } from 'zod';
import { listQuery, optionalText, requiredText } from './common.js';

const integer = (label, { min = 0, max }) =>
  z
    .number({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} debe ser un número.` })
    .int(`${label} debe ser un número entero.`)
    .min(min, min === 0 ? `${label} no puede ser negativo.` : `${label} debe ser al menos ${min}.`)
    .max(max, `${label} no puede pasar de ${max.toLocaleString('es-MX')}.`);

const code = z
  .string({ required_error: 'El código es obligatorio.', invalid_type_error: 'El código es obligatorio.' })
  .trim()
  .min(2, 'El código debe tener al menos 2 caracteres.')
  .max(40, 'El código no puede pasar de 40 caracteres.')
  .regex(/^[A-Za-z0-9_-]+$/, 'El código solo admite letras, números, guion y guion bajo.')
  .transform((value) => value.toUpperCase());

const name = requiredText('El nombre', 120).refine((value) => value.length >= 2, 'El nombre debe tener al menos 2 caracteres.');
const unit = requiredText('La unidad de medida', 20);
const minStock = integer('El stock mínimo', { max: 1000000 });

export const createPartSchema = z.object({
  code,
  name,
  description: optionalText('La descripción', 500),
  unit,
  minStock,
  initialStock: integer('El stock inicial', { max: 1000000 }),
});

/** Edición parcial: el código y el stock no cambian por esta vía (el stock solo cambia con movimientos). */
export const updatePartSchema = z
  .object({
    name: name.optional(),
    description: optionalText('La descripción', 500),
    unit: unit.optional(),
    minStock: minStock.optional(),
    active: z.boolean({ invalid_type_error: 'El estado activo no es válido.' }).optional(),
  })
  .strict('Solo se pueden modificar el nombre, la descripción, la unidad, el stock mínimo y el estado.')
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

export const STOCK_STATUS_VALUES = ['SUFICIENTE', 'BAJO', 'AGOTADO'];

export const listPartsQuery = listQuery.extend({
  stockStatus: z.enum(STOCK_STATUS_VALUES, { message: 'El estado de stock no es válido.' }).optional(),
  active: z
    .enum(['true', 'false'], { message: 'El filtro de activas no es válido.' })
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),
});

const reason = z
  .string({ invalid_type_error: 'El motivo no es válido.' })
  .trim()
  .max(255, 'El motivo no puede pasar de 255 caracteres.');

/** Movimiento manual: entrada de mercancía o ajuste por conteo. `OUT` solo nace del uso en una orden. */
export const movementSchema = z.discriminatedUnion(
  'type',
  [
    z.object({
      type: z.literal('IN'),
      quantity: integer('La cantidad', { min: 1, max: 100000 }),
      reason: reason.optional().transform((value) => value || undefined),
    }),
    z.object({
      type: z.literal('ADJUSTMENT'),
      countedQuantity: integer('La cantidad contada', { max: 1000000 }),
      reason: reason.min(5, 'El motivo del ajuste debe tener al menos 5 caracteres.'),
    }),
  ],
  { errorMap: () => ({ message: 'El tipo de movimiento debe ser IN (entrada) o ADJUSTMENT (ajuste).' }) },
);

export const movementsQuery = listQuery.pick({ page: true, pageSize: true });
