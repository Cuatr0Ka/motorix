import { AppError } from '../utils/AppError.js';
import { verifyToken } from '../utils/jwt.js';
import * as userModel from '../models/userModel.js';

/**
 * Exige un token válido y, en CADA petición, consulta al usuario en la base para confirmar que sigue
 * activo y obtener su rol vigente. Así un cambio de rol o una desactivación rigen de inmediato.
 */
export async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) throw AppError.unauthenticated();

    let userId;
    try {
      userId = verifyToken(token);
    } catch {
      throw AppError.unauthenticated('Tu sesión no es válida o expiró. Inicia sesión de nuevo.');
    }

    const user = await userModel.findById(userId);
    if (!user || !user.active) {
      throw AppError.unauthenticated('Tu cuenta no está disponible. Contacta al administrador.');
    }

    req.user = user;
    return next();
  } catch (error) {
    return next(error);
  }
}
