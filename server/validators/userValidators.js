import { z } from 'zod';
import { listQuery, requiredText } from './common.js';

const ROLE_VALUES = ['ADMIN', 'RECEPTIONIST', 'MECHANIC'];
const roleMessage = 'El rol debe ser ADMIN, RECEPTIONIST o MECHANIC.';

/** Usuario: 3–50 caracteres; letras, números, `.`, `_`, `-`; sin `@` para no confundirse con un correo. */
const username = z
  .string({ required_error: 'El usuario es obligatorio.', invalid_type_error: 'El usuario es obligatorio.' })
  .trim()
  .min(3, 'El usuario debe tener al menos 3 caracteres.')
  .max(50, 'El usuario no puede pasar de 50 caracteres.')
  .regex(/^[A-Za-z0-9._-]+$/, 'El usuario solo puede llevar letras, números, punto, guion y guion bajo.');

const email = z
  .string({ required_error: 'El correo es obligatorio.', invalid_type_error: 'El correo es obligatorio.' })
  .trim()
  .toLowerCase()
  .min(1, 'El correo es obligatorio.')
  .max(254, 'El correo no puede pasar de 254 caracteres.')
  .email('El correo no es válido.');

const role = z.enum(ROLE_VALUES, {
  // zod no admite combinar errorMap con required_error/invalid_type_error.
  errorMap: (issue, ctx) => ({
    message: ctx.data === undefined ? 'El rol es obligatorio.' : roleMessage,
  }),
});

/** La política de contraseña (mayúscula, minúscula, número) la aplica el servicio y responde 422. */
export const passwordField = (label) =>
  z
    .string({ required_error: `${label} es obligatoria.`, invalid_type_error: `${label} es obligatoria.` })
    .min(1, `${label} es obligatoria.`)
    .max(200, `${label} es demasiado larga.`);

export const createUserSchema = z.object({
  username,
  name: requiredText('El nombre', 120),
  email,
  role,
  password: passwordField('La contraseña'),
});

/** Edición parcial: nombre, correo, rol y estado. El usuario y la contraseña no se cambian por esta ruta. */
export const updateUserSchema = z
  .object({
    name: requiredText('El nombre', 120).optional(),
    email: email.optional(),
    role: role.optional(),
    active: z.boolean({ invalid_type_error: 'El estado no es válido.' }).optional(),
  })
  .refine((data) => Object.values(data).some((value) => value !== undefined), {
    message: 'Envía al menos un campo para actualizar.',
  });

export const listUsersQuery = listQuery.extend({
  role: z.enum(ROLE_VALUES, { errorMap: () => ({ message: roleMessage }) }).optional(),
  active: z
    .enum(['true', 'false'], { errorMap: () => ({ message: 'El estado debe ser true o false.' }) })
    .transform((value) => value === 'true')
    .optional(),
});

export const changePasswordSchema = z.object({
  currentPassword: passwordField('La contraseña actual'),
  newPassword: passwordField('La contraseña nueva'),
});
