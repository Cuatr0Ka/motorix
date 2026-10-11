import { ZodError } from 'zod';
import { AppError } from '../utils/AppError.js';

/** 404 para rutas inexistentes. */
export function notFoundHandler(req, res, next) {
  next(AppError.notFound('La ruta solicitada no existe.'));
}

/** Convierte un error de zod en el detalle por campo del contrato de la API. */
export function zodDetails(error) {
  return error.issues.map((issue) => ({
    field: issue.path.join('.') || 'body',
    message: issue.message,
  }));
}

/**
 * Manejador central de errores. Nunca devuelve trazas de pila ni mensajes del motor de base de datos.
 */
// eslint-disable-next-line no-unused-vars
export function errorHandler(error, req, res, next) {
  let appError = error;

  if (error instanceof ZodError) {
    appError = AppError.validation('Revisa los campos marcados.', zodDetails(error));
  } else if (error?.type === 'entity.parse.failed') {
    appError = AppError.validation('El cuerpo de la petición no es un JSON válido.');
  } else if (!(error instanceof AppError)) {
    // Error inesperado: se registra en el servidor y al usuario se le responde algo genérico.
    if (process.env.NODE_ENV !== 'test') {
      console.error('[error]', error);
    }
    appError = new AppError(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado. Inténtalo de nuevo.');
  }

  const body = { error: { code: appError.code, message: appError.message } };
  if (appError.details !== undefined) body.error.details = appError.details;
  return res.status(appError.status).json(body);
}
