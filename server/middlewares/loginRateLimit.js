import rateLimit from 'express-rate-limit';

/** Máximo de intentos de inicio de sesión por IP en la ventana (complementa el bloqueo por cuenta). */
export const LOGIN_MAX_PER_IP = 20;
export const LOGIN_WINDOW_MINUTES = 15;

/**
 * Límite de peticiones por IP para el inicio de sesión. Evita probar muchas cuentas desde un mismo origen.
 * En pruebas se desactiva para no interferir con los flujos que inician sesión muchas veces.
 */
export function createLoginRateLimit({ max = LOGIN_MAX_PER_IP, skip = () => process.env.NODE_ENV === 'test' } = {}) {
  return rateLimit({
    windowMs: LOGIN_WINDOW_MINUTES * 60 * 1000,
    max,
    skip,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) =>
      res.status(429).json({
        error: { code: 'TOO_MANY_REQUESTS', message: 'Demasiados intentos de inicio de sesión. Inténtalo más tarde.' },
      }),
  });
}

export const loginRateLimit = createLoginRateLimit();
