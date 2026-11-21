import { z } from 'zod';

const shopName = z
  .string({ invalid_type_error: 'El nombre del taller no es válido.' })
  .trim()
  .min(1, 'El nombre del taller es obligatorio.')
  .max(100, 'El nombre del taller no puede pasar de 100 caracteres.');

const shopAddress = z
  .string({ invalid_type_error: 'La dirección no es válida.' })
  .trim()
  .max(200, 'La dirección no puede pasar de 200 caracteres.');

const shopPhone = z
  .string({ invalid_type_error: 'El teléfono no es válido.' })
  .trim()
  .max(20, 'El teléfono no puede pasar de 20 caracteres.')
  .regex(/^[0-9+\-() ]*$/, 'El teléfono solo puede llevar dígitos, espacios, +, - y paréntesis.');

const warnDays = z
  .number({ invalid_type_error: 'El margen en días debe ser un número.' })
  .int('El margen en días debe ser un número entero.')
  .min(1, 'El margen en días debe estar entre 1 y 365.')
  .max(365, 'El margen en días debe estar entre 1 y 365.');

const warnKm = z
  .number({ invalid_type_error: 'El margen en kilómetros debe ser un número.' })
  .int('El margen en kilómetros debe ser un número entero.')
  .min(1, 'El margen en kilómetros debe estar entre 1 y 100 000.')
  .max(100000, 'El margen en kilómetros debe estar entre 1 y 100 000.');

/**
 * Cuerpo de `PUT /settings`: todos los campos son opcionales, pero debe venir al menos uno. Es estricto: los campos
 * desconocidos se rechazan.
 */
export const updateSettingsSchema = z
  .object({
    shop: z
      .object({ name: shopName.optional(), address: shopAddress.optional(), phone: shopPhone.optional() })
      .strict('Hay campos del taller que no se pueden enviar.')
      .optional(),
    maintenance: z
      .object({ warnDays: warnDays.optional(), warnKm: warnKm.optional() })
      .strict('Hay campos de mantenimiento que no se pueden enviar.')
      .optional(),
  })
  .strict('Hay campos que no se pueden enviar.')
  .refine(
    (value) => Object.values(value.shop ?? {}).some((v) => v !== undefined) || Object.values(value.maintenance ?? {}).some((v) => v !== undefined),
    { message: 'Indica al menos un dato para guardar.' },
  );
