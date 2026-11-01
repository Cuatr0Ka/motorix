import { z } from 'zod';
import { listQuery, optionalText, requiredText } from './common.js';

const integer = (label, { min = 0, max }) =>
  z
    .number({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} debe ser un número.` })
    .int(`${label} debe ser un número entero.`)
    .min(min, min === 0 ? `${label} no puede ser negativo.` : `${label} debe ser al menos ${min}.`)
    .max(max, `${label} no puede pasar de ${max.toLocaleString('es-MX')}.`);

const MAX_PRICE_CENTS = 999999999; // 9 999 999.99
const NULL_MARK = '__NULL__';

/**
 * Precio en pesos: acepta número o cadena decimal y devuelve una cadena con dos decimales exactos ("180.00").
 * Rechaza negativos, texto, más de dos decimales y más de 9 999 999.99. Con `positive` exige mayor a cero (el
 * precio de venta); sin él acepta cero (el precio de compra). Un `null` solo pasa si el campo es `.nullable()`.
 */
function price(label, { positive = false, nullMessage } = {}) {
  return z
    .preprocess(
      (raw) => {
        if (raw === null) return NULL_MARK;
        if (typeof raw === 'number') return Number.isFinite(raw) ? String(raw) : 'NaN';
        return typeof raw === 'string' ? raw.trim() : raw;
      },
      z.string({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} debe ser un número.` }),
    )
    .superRefine((text, ctx) => {
      const fail = (message) => ctx.addIssue({ code: z.ZodIssueCode.custom, message });
      if (text === NULL_MARK) return fail(nullMessage ?? `${label} debe ser un número.`);
      if (!/^-?\d+(\.\d+)?$/.test(text)) return fail(`${label} debe ser un número.`);
      if (text.startsWith('-')) return fail(`${label} no puede ser negativo.`);
      const [entero, decimales = ''] = text.split('.');
      if (decimales.length > 2) return fail(`${label} puede tener a lo sumo dos decimales.`);
      const centavos = Number(entero) * 100 + Number(decimales.padEnd(2, '0'));
      if (centavos > MAX_PRICE_CENTS) return fail(`${label} no puede pasar de 9 999 999.99.`);
      if (positive && centavos === 0) return fail(`${label} debe ser mayor a cero.`);
      return undefined;
    })
    .transform((text) => {
      const [entero, decimales = ''] = text.split('.');
      return `${Number(entero)}.${decimales.padEnd(2, '0')}`;
    });
}

const category = optionalText('La categoría', 60);
const brand = optionalText('La marca', 60);
const purchasePrice = price('El precio de compra').nullable().optional();
const salePrice = price('El precio de venta', { positive: true, nullMessage: 'El precio de venta no se puede borrar una vez capturado.' }).optional();
const confirmBelowCost = z.boolean({ invalid_type_error: 'La confirmación no es válida.' }).optional();

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
  category,
  brand,
  purchasePrice,
  salePrice,
  confirmBelowCost,
});

/** Edición parcial: el código y el stock no cambian por esta vía (el stock solo cambia con movimientos). */
export const updatePartSchema = z
  .object({
    name: name.optional(),
    description: optionalText('La descripción', 500),
    unit: unit.optional(),
    minStock: minStock.optional(),
    active: z.boolean({ invalid_type_error: 'El estado activo no es válido.' }).optional(),
    category,
    brand,
    purchasePrice,
    salePrice,
    confirmBelowCost,
  })
  .strict('Solo se pueden modificar el nombre, la descripción, la unidad, el stock mínimo, el estado, la categoría, la marca y los precios.')
  .refine((data) => Object.entries(data).some(([clave, value]) => clave !== 'confirmBelowCost' && value !== undefined), {
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
