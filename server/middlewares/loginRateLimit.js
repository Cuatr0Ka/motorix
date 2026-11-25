import { AppError } from '../utils/AppError.js';

/** Máximo de intentos de inicio de sesión por IP en la ventana (complementa el bloqueo por cuenta). */
export const LOGIN_MAX_PER_IP = 20;
export const LOGIN_WINDOW_MINUTES = 15;

/**
 * Límite de peticiones por IP para el inicio de sesión, con un contador en memoria (sin dependencias nuevas).
 * Evita probar muchas cuentas desde un mismo origen. El contador se reinicia al reiniciar el servidor, lo cual es
 * suficiente para una sola instancia. En pruebas se desactiva para no interferir con los flujos que inician sesión.
 */
export function createLoginRateLimit({
  max = LOGIN_MAX_PER_IP,
  windowMs = LOGIN_WINDOW_MINUTES * 60 * 1000,
  skip = () => process.env.NODE_ENV === 'test',
  now = () => Date.now(),
} = {}) {
  const hits = new Map(); // ip -> { count, resetAt }

  return function loginRateLimit(req, res, next) {
    if (skip()) return next();
    const time = now();
    // Limpieza de ventanas vencidas para que el mapa no crezca sin control.
    for (const [ip, entry] of hits) if (entry.resetAt <= time) hits.delete(ip);

    const ip = req.ip ?? 'desconocida';
    const entry = hits.get(ip) ?? { count: 0, resetAt: time + windowMs };
    entry.count += 1;
    hits.set(ip, entry);

    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - time) / 1000)));
      return next(new AppError(429, 'TOO_MANY_REQUESTS', 'Demasiados intentos de inicio de sesión. Inténtalo más tarde.'));
    }
    return next();
  };
}

export const loginRateLimit = createLoginRateLimit();
