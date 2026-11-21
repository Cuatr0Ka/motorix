import { z } from 'zod';
import { ACTIONS } from '../services/auditService.js';

const date = (label) =>
  z
    .string({ invalid_type_error: `${label} no es válida.` })
    .regex(/^\d{4}-\d{2}-\d{2}$/, `${label} debe tener el formato AAAA-MM-DD.`)
    .refine((value) => {
      const parsed = new Date(`${value}T00:00:00Z`);
      return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
    }, `${label} no es válida.`);

/** Filtros de la bitácora: fechas AAAA-MM-DD, persona, acción conocida y paginación de hasta 100. */
export const auditLogQuery = z.object({
  from: date('La fecha inicial').optional(),
  to: date('La fecha final').optional(),
  userId: z.coerce.number({ invalid_type_error: 'El usuario no es válido.' }).int('El usuario no es válido.').positive('El usuario no es válido.').optional(),
  action: z.enum(Object.values(ACTIONS), { errorMap: () => ({ message: 'La acción no es válida.' }) }).optional(),
  page: z.coerce.number().int().min(1, 'La página no es válida.').default(1),
  pageSize: z.coerce.number().int().min(1, 'El tamaño de página no es válido.').max(100, 'El tamaño de página no puede pasar de 100.').default(20),
});
