import { AppError } from '../utils/AppError.js';
import { zodDetails } from './errorHandler.js';

/**
 * Valida `body`, `query` y `params` con esquemas zod y reemplaza los valores por los ya
 * normalizados. Ejemplo: validate({ body: loginSchema }).
 */
export function validate(schemas) {
  return (req, res, next) => {
    for (const part of ['params', 'query', 'body']) {
      const schema = schemas[part];
      if (!schema) continue;
      const result = schema.safeParse(req[part] ?? {});
      if (!result.success) {
        return next(AppError.validation('Revisa los campos marcados.', zodDetails(result.error)));
      }
      // En Express 4 `req.query` es asignable; se guarda el valor validado en una propiedad paralela.
      if (part === 'query') req.validQuery = result.data;
      else req[part] = result.data;
    }
    return next();
  };
}
