import { z } from 'zod';
import { CLIENT_NOTICE_REASONS, isValidNoticeKey } from '../services/noticeRules.js';

/** Cuerpo de `POST /notifications/read`: de 1 a 50 claves de aviso bien formadas. */
export const readNoticesSchema = z
  .object({
    keys: z
      .array(
        z
          .string({ invalid_type_error: 'Las claves de aviso no son válidas.' })
          .refine(isValidNoticeKey, 'La clave de aviso no es válida.'),
        { required_error: 'Indica las claves de los avisos.', invalid_type_error: 'Las claves de aviso no son válidas.' },
      )
      .min(1, 'Indica al menos una clave de aviso.')
      .max(50, 'No se pueden marcar más de 50 avisos a la vez.'),
  })
  .strict('Hay campos que no se pueden enviar.');

/**
 * Cuerpo de `POST /client-notices`. Es estricto: no acepta nota ni ningún otro campo, porque solo se registra
 * quién avisó y cuándo (D-02).
 */
export const createClientNoticeSchema = z
  .object({
    reason: z.enum(Object.values(CLIENT_NOTICE_REASONS), {
      errorMap: () => ({ message: 'El motivo del aviso no es válido.' }),
    }),
    factId: z
      .number({
        required_error: 'El identificador del hecho es obligatorio.',
        invalid_type_error: 'El identificador del hecho no es válido.',
      })
      .int('El identificador del hecho no es válido.')
      .positive('El identificador del hecho no es válido.'),
  })
  .strict('Hay campos que no se pueden enviar.');
