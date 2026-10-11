/**
 * Error de negocio con código estable, estado HTTP y mensaje en español.
 * El manejador central lo convierte en la respuesta JSON de error.
 */
export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static validation(message = 'Revisa los campos marcados.', details) {
    return new AppError(400, 'VALIDATION_ERROR', message, details);
  }

  static unauthenticated(message = 'Debes iniciar sesión para continuar.') {
    return new AppError(401, 'UNAUTHENTICATED', message);
  }

  static invalidCredentials() {
    return new AppError(401, 'INVALID_CREDENTIALS', 'Usuario o contraseña incorrectos.');
  }

  static forbidden(message = 'No tienes permiso para realizar esta acción.') {
    return new AppError(403, 'FORBIDDEN', message);
  }

  static notFound(message = 'No se encontró el recurso solicitado.') {
    return new AppError(404, 'NOT_FOUND', message);
  }

  static conflict(code, message, details) {
    return new AppError(409, code, message, details);
  }

  static unprocessable(code, message, details) {
    return new AppError(422, code, message, details);
  }
}
