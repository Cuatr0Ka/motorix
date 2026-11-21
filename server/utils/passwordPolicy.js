import { PASSWORD_MIN_LENGTH } from '../config/security.js';

export { PASSWORD_MIN_LENGTH };

/**
 * Política mínima de contraseñas (FR-007): al menos 10 caracteres (Sprint 7) con una mayúscula, una minúscula y un número.
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
