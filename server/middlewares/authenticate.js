import { AppError } from '../utils/AppError.js';
import { verifyToken } from '../utils/jwt.js';
import * as termsModel from '../models/termsModel.js';
import * as userModel from '../models/userModel.js';

/**
 * Rutas que un usuario puede usar AUNQUE todavía no haya aceptado la versión vigente de los términos: leerlos, aceptarlos
 * y consultar su propia sesión. Es una lista fija (método y ruta exactos); cualquier otra ruta autenticada exige la aceptación.
 */
export const TERMS_EXEMPT_ROUTES = Object.freeze(['GET /api/terms/current', 'POST /api/terms/accept', 'GET /api/auth/me']);

const routeKey = (req) => `${req.method} ${req.originalUrl.split('?')[0].replace(/\/+$/, '')}`;

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

    // Sprint 7: sin la aceptación de la versión vigente de los términos no se opera (salvo las rutas de la lista fija).
    if (!TERMS_EXEMPT_ROUTES.includes(routeKey(req))) {
      const current = await termsModel.findCurrent();
      if (current && !(await termsModel.hasAccepted(user.id, current.id))) {
        throw new AppError(403, 'TERMS_NOT_ACCEPTED', 'Debes aceptar los términos y condiciones para continuar.', {
          version: current.version,
          versionId: current.id,
        });
      }
    }

    req.user = user;
    return next();
  } catch (error) {
    return next(error);
  }
}
