import { z } from 'zod';

/** Importe en dinero: entre 0 y 9 999 999.99, con hasta dos decimales. Acepta número o cadena decimal. */
export function money(label = 'El importe') {
  return z
    .preprocess(
      (value) => (typeof value === 'string' && value.trim() !== '' ? Number(value.trim()) : value),
      z
        .number({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} debe ser un número.` })
        .finite(`${label} debe ser un número.`)
        .min(0, `${label} no puede ser negativo.`)
        .max(9999999.99, `${label} no puede pasar de 9 999 999.99.`)
        .refine((value) => Math.abs(value * 100 - Math.round(value * 100)) < 1e-6, `${label} admite hasta dos decimales.`),
    )
    .transform((value) => Math.round(value * 100) / 100);
}

/** Kilometraje de entrada: entero de 0 a 2 000 000. */
export const entryMileage = z
  .number({ required_error: 'El kilometraje de entrada es obligatorio.', invalid_type_error: 'El kilometraje debe ser un número.' })
  .int('El kilometraje debe ser un número entero.')
  .min(0, 'El kilometraje no puede ser negativo.')
  .max(2000000, 'El kilometraje no puede pasar de 2 000 000.');

/** Fecha y hora ISO 8601 válida; se convierte a Date. */
export const isoDateTime = (label = 'La fecha y hora') =>
  z
    .string({ required_error: `${label} es obligatoria.`, invalid_type_error: `${label} no es válida.` })
    .trim()
    .refine((value) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value) && !Number.isNaN(Date.parse(value)), `${label} no es válida.`)
    // Se trunca a segundos: la base guarda DATETIME sin fracciones y así el horario se compara igual.
    .transform((value) => new Date(Math.floor(Date.parse(value) / 1000) * 1000));

/** Texto largo opcional (hasta 5 000 caracteres): se recorta y, si queda vacío o es null, pasa a null. */
export function longText(label) {
  return z.preprocess(
    (value) => (typeof value === 'string' ? value.trim() || null : value),
    z
      .string({ invalid_type_error: `${label} no es válido.` })
      .max(5000, `${label} no puede pasar de 5 000 caracteres.`)
      .nullable()
      .optional(),
  );
}
