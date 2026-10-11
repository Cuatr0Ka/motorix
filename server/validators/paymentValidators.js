import { z } from 'zod';
import { listQuery } from './common.js';
import { PAYMENT_METHODS, PAYMENT_STATUSES } from '../services/paymentRules.js';

/** Importe opcional: número o cadena decimal positivo con hasta dos decimales. */
const amount = z.preprocess(
  (value) => (typeof value === 'string' && value.trim() !== '' ? Number(value.trim()) : value),
  z
    .number({ invalid_type_error: 'El importe debe ser un número.' })
    .finite('El importe debe ser un número.')
    .positive('El importe debe ser mayor a cero.')
    .max(9999999.99, 'El importe no puede pasar de 9 999 999.99.')
    .refine((value) => Math.abs(value * 100 - Math.round(value * 100)) < 1e-6, 'El importe admite hasta dos decimales.')
    .optional(),
);

/** Referencia opcional recortada; vacía → ausente. La regla de «no parecer tarjeta» la aplica el servicio. */
const reference = z.preprocess(
  (value) => (typeof value === 'string' ? value.trim() || undefined : value === null ? undefined : value),
  z.string({ invalid_type_error: 'La referencia no es válida.' }).max(100, 'La referencia no puede pasar de 100 caracteres.').optional(),
);

export const createPaymentSchema = z
  .object({
    method: z.enum(PAYMENT_METHODS, {
      required_error: 'El método de pago es obligatorio.',
      invalid_type_error: 'El método de pago no es válido.',
      message: 'El método de pago no es válido.',
    }),
    amount,
    reference,
  })
  .strict('Solo se admiten el método, el importe y la referencia.');

export const listPaymentsQuery = listQuery.extend({
  status: z.enum(PAYMENT_STATUSES, { message: 'El estado no es válido.' }).optional(),
  method: z.enum(PAYMENT_METHODS, { message: 'El método de pago no es válido.' }).optional(),
});
