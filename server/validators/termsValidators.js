import { z } from 'zod';

export const acceptTermsSchema = z
  .object({
    versionId: z
      .number({ required_error: 'La versión es obligatoria.', invalid_type_error: 'La versión no es válida.' })
      .int('La versión no es válida.')
      .positive('La versión no es válida.'),
  })
  .strict('Hay campos que no se pueden enviar.');

export const acceptancesQuery = z.object({
  versionId: z.coerce.number({ invalid_type_error: 'La versión no es válida.' }).int('La versión no es válida.').positive('La versión no es válida.').optional(),
  page: z.coerce.number().int().min(1, 'La página no es válida.').default(1),
  pageSize: z.coerce.number().int().min(1, 'El tamaño de página no es válido.').max(100, 'El tamaño de página no puede pasar de 100.').default(20),
});
