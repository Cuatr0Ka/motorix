import { z } from 'zod';

/** Texto opcional: se recorta y, si queda vacío o es null, se convierte en null. */
export function optionalText(label, max) {
  return z.preprocess(
    (value) => (typeof value === 'string' ? value.trim() || null : value),
    z
      .string({ invalid_type_error: `${label} no es válido.` })
      .max(max, `${label} no puede pasar de ${max} caracteres.`)
      .nullable()
      .optional(),
  );
}

/** Texto obligatorio recortado, con mensajes en español. */
export function requiredText(label, max) {
  return z
    .string({ required_error: `${label} es obligatorio.`, invalid_type_error: `${label} es obligatorio.` })
    .trim()
    .min(1, `${label} es obligatorio.`)
    .max(max, `${label} no puede pasar de ${max} caracteres.`);
}

/** Correo opcional: vacío → null; en minúsculas; con formato válido. */
export const optionalEmail = z.preprocess(
  (value) => (typeof value === 'string' ? value.trim().toLowerCase() || null : value),
  z
    .string({ invalid_type_error: 'El correo no es válido.' })
    .max(254, 'El correo no puede pasar de 254 caracteres.')
    .email('El correo no es válido.')
    .nullable()
    .optional(),
);

/** Parámetro `:id` numérico positivo. */
export const idParams = z.object({
  id: z.coerce
    .number({ invalid_type_error: 'El identificador no es válido.' })
    .int('El identificador no es válido.')
    .positive('El identificador no es válido.'),
});

/** Paginación y búsqueda de los listados (20 por defecto, máximo 100). */
export const listQuery = z.object({
  search: z
    .string()
    .trim()
    .max(100, 'La búsqueda no puede pasar de 100 caracteres.')
    .optional()
    .transform((value) => value || undefined),
  page: z.coerce.number().int('La página no es válida.').min(1, 'La página no es válida.').default(1),
  pageSize: z.coerce
    .number()
    .int('El tamaño de página no es válido.')
    .min(1, 'El tamaño de página no es válido.')
    .max(100, 'El tamaño de página no puede pasar de 100.')
    .default(20),
});
