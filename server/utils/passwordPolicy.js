export const PASSWORD_MIN_LENGTH = 8;

/**
 * Política mínima de contraseñas (FR-007): al menos 8 caracteres con una mayúscula, una minúscula y un número.
 * Devuelve el mensaje de incumplimiento o null si la contraseña es válida.
 */
export function checkPasswordPolicy(password) {
  if (typeof password !== 'string' || password.length < PASSWORD_MIN_LENGTH) {
    return `La contraseña debe tener al menos ${PASSWORD_MIN_LENGTH} caracteres.`;
  }
  if (!/[A-ZÁÉÍÓÚÑ]/.test(password)) return 'La contraseña debe incluir al menos una letra mayúscula.';
  if (!/[a-záéíóúñ]/.test(password)) return 'La contraseña debe incluir al menos una letra minúscula.';
  if (!/[0-9]/.test(password)) return 'La contraseña debe incluir al menos un número.';
  return null;
}
