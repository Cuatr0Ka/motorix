import { describe, expect, it, jest } from '@jest/globals';
import { authorize } from '../../middlewares/authorize.js';

function ejecutar(middleware, user) {
  const next = jest.fn();
  middleware({ user }, {}, next);
  return next.mock.calls[0][0];
}

describe('authorize', () => {
  it('test_permite_el_paso_a_un_rol_autorizado', () => {
    const error = ejecutar(authorize('ADMIN', 'RECEPTIONIST'), { role: 'RECEPTIONIST' });
    expect(error).toBeUndefined();
  });

  it('test_rechaza_con_403_a_un_rol_no_autorizado', () => {
    const error = ejecutar(authorize('ADMIN', 'RECEPTIONIST'), { role: 'MECHANIC' });
    expect(error.status).toBe(403);
    expect(error.code).toBe('FORBIDDEN');
  });

  it('test_rechaza_con_401_si_no_hay_usuario_autenticado', () => {
    const error = ejecutar(authorize('ADMIN'), undefined);
    expect(error.status).toBe(401);
  });
});
