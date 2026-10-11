import { z } from 'zod';
import { listQuery, optionalEmail, optionalText, requiredText } from './common.js';

const PHONE_FORMAT = /^[0-9+\s().-]+$/;

/** Primer problema del teléfono (o null): así la API reporta un solo error por campo. */
function phoneProblem(value) {
  if (value.length === 0) return 'El teléfono es obligatorio.';
  if (value.length > 20) return 'El teléfono no puede pasar de 20 caracteres.';
  if (!PHONE_FORMAT.test(value)) return 'El teléfono solo puede llevar dígitos, +, espacios, guiones o paréntesis.';
  if (value.replace(/\D/g, '').length < 7) return 'El teléfono debe tener al menos 7 dígitos.';
  return null;
}

/** Teléfono: dígitos con +, espacios, guiones o paréntesis; máximo 20 caracteres y mínimo 7 dígitos. */
const phone = z
  .string({ required_error: 'El teléfono es obligatorio.', invalid_type_error: 'El teléfono es obligatorio.' })
  .trim()
  .superRefine((value, ctx) => {
    const problem = phoneProblem(value);
    if (problem) ctx.addIssue({ code: z.ZodIssueCode.custom, message: problem });
  });

export const createClientSchema = z.object({
  name: requiredText('El nombre', 120),
  phone,
  email: optionalEmail,
  address: optionalText('La dirección', 255),
  confirmDuplicatePhone: z.boolean().optional().default(false),
});

/** Edición parcial con las mismas reglas del alta; debe enviarse al menos un campo del cliente. */
export const updateClientSchema = createClientSchema
  .partial()
  .refine(
    (data) => Object.entries(data).some(([key, value]) => key !== 'confirmDuplicatePhone' && value !== undefined),
    { message: 'Envía al menos un campo para actualizar.' },
  );

export const listClientsQuery = listQuery;
