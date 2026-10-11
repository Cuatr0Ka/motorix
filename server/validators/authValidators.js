import { z } from 'zod';

/** Inicio de sesión: un único campo que acepta usuario o correo. */
export const loginSchema = z.object({
  identifier: z
    .string({ required_error: 'Escribe tu usuario o correo.', invalid_type_error: 'Escribe tu usuario o correo.' })
    .trim()
    .min(1, 'Escribe tu usuario o correo.')
    .max(254, 'El usuario o correo es demasiado largo.'),
  password: z
    .string({ required_error: 'Escribe tu contraseña.', invalid_type_error: 'Escribe tu contraseña.' })
    .min(1, 'Escribe tu contraseña.')
    .max(200, 'La contraseña es demasiado larga.'),
});
