/** Envuelve un controlador asíncrono para que sus errores lleguen al manejador central (Express 4). */
export const asyncHandler = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);
