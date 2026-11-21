/**
 * Constantes de seguridad de la sesión y de las contraseñas (Sprint 7). Se dejan juntas para que las pruebas y el
 * cliente usen los mismos valores que el servidor.
 */

/** Minutos sin actividad después de los cuales la sesión se cierra (FR-027). */
export const INACTIVITY_MINUTES = 30;

/** Cada cuántos segundos como máximo se escribe la última actividad de un usuario (evita una escritura por petición). */
export const ACTIVITY_WRITE_SECONDS = 60;

/** Longitud mínima de una contraseña nueva (FR-026). */
export const PASSWORD_MIN_LENGTH = 10;
