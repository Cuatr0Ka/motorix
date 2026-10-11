import { describe, expect, it, jest } from '@jest/globals';
import { z } from 'zod';
import { errorHandler } from '../../middlewares/errorHandler.js';
import { AppError } from '../../utils/AppError.js';

function responder(error) {
  const res = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
  errorHandler(error, {}, res, jest.fn());
  return { status: res.status.mock.calls[0][0], body: res.json.mock.calls[0][0] };
}

describe('errorHandler', () => {
  it('test_devuelve_el_codigo_y_mensaje_de_un_AppError', () => {
    const { status, body } = responder(AppError.conflict('EMAIL_DUPLICATE', 'El correo ya está registrado.'));
    expect(status).toBe(409);
    expect(body).toEqual({ error: { code: 'EMAIL_DUPLICATE', message: 'El correo ya está registrado.' } });
  });

  it('test_traduce_un_error_de_zod_a_detalles_por_campo', () => {
    const resultado = z.object({ email: z.string().email('El correo no es válido.') }).safeParse({ email: 'x' });
    const { status, body } = responder(resultado.error);
    expect(status).toBe(400);
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.details).toEqual([{ field: 'email', message: 'El correo no es válido.' }]);
  });

  it('test_un_error_inesperado_no_expone_trazas_ni_mensajes_internos', () => {
    const error = new Error("Table 'motorix.users' doesn't exist");
    error.stack = 'Error: secreto\n    at archivo.js:1:1';
    const { status, body } = responder(error);
    expect(status).toBe(500);
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(JSON.stringify(body)).not.toMatch(/motorix|stack|archivo\.js|doesn't exist/);
  });

  it('test_un_json_malformado_responde_400', () => {
    const { status, body } = responder(Object.assign(new Error('x'), { type: 'entity.parse.failed' }));
    expect(status).toBe(400);
    expect(body.error.code).toBe('VALIDATION_ERROR');
  });
});
