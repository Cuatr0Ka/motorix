import { z } from 'zod';

const day = (label) =>
  z
    .string({ required_error: `${label} es obligatoria.`, invalid_type_error: `${label} no es válida.` })
    .trim()
    .min(1, `${label} es obligatoria.`);

/** Periodo del reporte (`from` y `to`, validados a fondo por reportRules) y formato opcional `xlsx` (Excel). */
export const reportQuery = z.object({
  from: day('La fecha inicial'),
  to: day('La fecha final'),
  format: z.enum(['xlsx'], { errorMap: () => ({ message: 'El formato no es válido. Usa xlsx.' }) }).optional(),
});
