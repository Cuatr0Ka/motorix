import bcrypt from 'bcryptjs';
import { getJwtConfig } from '../config/env.js';
import * as userModel from '../models/userModel.js';
import { AppError } from '../utils/AppError.js';
import { signToken } from '../utils/jwt.js';
import { ACTIONS, record as recordAudit } from './auditService.js';
import { assertPasswordPolicy } from './userService.js';

export const MAX_FAILED_ATTEMPTS = 5;
export const LOCK_MINUTES = 15;

// Hash de relleno para que comparar contra una cuenta inexistente tarde lo mismo que contra una real.
const DUMMY_HASH = bcrypt.hashSync('relleno-para-igualar-tiempos', 10);

/** Datos públicos del usuario que viajan al cliente (nunca el hash ni datos de bloqueo). */
export function toPublicUser(user) {
  return { id: user.id, username: user.username, name: user.name, email: user.email, role: user.role };
}

function accountLocked(secondsLeft) {
  const minutes = Math.max(1, Math.ceil(secondsLeft / 60));
  return new AppError(
    423,
    'ACCOUNT_LOCKED',
    `La cuenta está bloqueada temporalmente por varios intentos fallidos. Inténtalo de nuevo en ${minutes} minuto(s).`,
    { retryAfterSeconds: secondsLeft },
  );
}

/**
 * Inicia sesión con usuario o correo. Los fallos de credenciales siempre devuelven el mismo mensaje
 * genérico; tras 5 fallos consecutivos la cuenta se bloquea 15 minutos.
 */
export async function login(identifier, password) {
  const record = await userModel.findByIdentifier(identifier);

  if (!record) {
    await bcrypt.compare(password, DUMMY_HASH);
    throw AppError.invalidCredentials();
  }
  if (!record.user.active) {
    await bcrypt.compare(password, DUMMY_HASH);
    throw AppError.invalidCredentials();
  }
  if (record.isLocked) throw accountLocked(record.lockSecondsLeft);

  const matches = await bcrypt.compare(password, record.passwordHash);
  if (!matches) {
    const result = await userModel.registerFailedAttempt(record.user.id, MAX_FAILED_ATTEMPTS, LOCK_MINUTES);
    // Bitácora: solo de cuentas que existen, atribuido a esa cuenta y SIN guardar lo tecleado (los intentos con cuentas
    // inexistentes no se registran).
    await recordAudit({
      actor: record.user,
      action: ACTIONS.LOGIN_FAILED,
      entityType: 'user',
      entityId: record.user.id,
      summary: 'Intento de inicio de sesión fallido',
    });
    if (result.locked) {
      await recordAudit({
        actor: record.user,
        action: ACTIONS.ACCOUNT_LOCKED,
        entityType: 'user',
        entityId: record.user.id,
        summary: `Cuenta bloqueada ${LOCK_MINUTES} minutos por ${MAX_FAILED_ATTEMPTS} intentos fallidos`,
      });
      throw accountLocked(result.lockSecondsLeft);
    }
    throw AppError.invalidCredentials();
  }

  if (record.failedLoginAttempts > 0) await userModel.resetFailures(record.user.id);
  // El inicio de sesión fija la última actividad (una cuenta inactiva por tiempo puede volver a entrar).
  await userModel.touchActivity(record.user.id, 0, { force: true });

  return {
    token: signToken(record.user.id),
    expiresIn: getJwtConfig().jwtExpiresInSeconds,
    user: toPublicUser(record.user),
  };
}

/**
 * Cambia la contraseña propia: exige la actual, que la nueva sea distinta y que cumpla la política mínima.
 */
export async function changePassword(userId, currentPassword, newPassword) {
  const currentHash = await userModel.getPasswordHash(userId);
  if (!currentHash || !(await bcrypt.compare(currentPassword, currentHash))) {
    throw AppError.invalidCredentials();
  }
  if (newPassword === currentPassword) {
    throw AppError.unprocessable('SAME_PASSWORD', 'La contraseña nueva debe ser distinta a la actual.');
  }
  assertPasswordPolicy(newPassword);

  await userModel.updatePassword(userId, await bcrypt.hash(newPassword, 10));
  await recordAudit({
    actor: { id: userId },
    action: ACTIONS.PASSWORD_CHANGED,
    entityType: 'user',
    entityId: userId,
    summary: 'Cambió su propia contraseña',
  });
  return { changed: true };
}

/** Perfil de la persona autenticada, con el rol vigente cargado por el middleware. */
export function getProfile(user) {
  return toPublicUser(user);
}
