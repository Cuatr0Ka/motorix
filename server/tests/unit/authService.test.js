import { beforeEach, describe, expect, it, jest } from '@jest/globals';
import bcrypt from 'bcryptjs';

// Se simula el modelo de usuarios para probar solo la lógica de bloqueo del servicio.
const userModel = {
  findByIdentifier: jest.fn(),
  registerFailedAttempt: jest.fn(),
  resetFailures: jest.fn(),
};
jest.unstable_mockModule('../../models/userModel.js', () => userModel);

const { login, MAX_FAILED_ATTEMPTS, LOCK_MINUTES } = await import('../../services/authService.js');

const hash = await bcrypt.hash('Correcta2026', 4);
const registro = (extra = {}) => ({
  user: { id: 1, username: 'ana', name: 'Ana', email: 'ana@x.local', role: 'ADMIN', active: true },
  passwordHash: hash,
  failedLoginAttempts: 0,
  isLocked: false,
  lockSecondsLeft: 0,
  ...extra,
});

beforeEach(() => {
  jest.clearAllMocks();
  process.env.JWT_SECRET ||= 'secreto-de-prueba-unitaria';
});

describe('authService.login', () => {
  it('test_define_5_intentos_y_15_minutos_de_bloqueo', () => {
    expect(MAX_FAILED_ATTEMPTS).toBe(5);
    expect(LOCK_MINUTES).toBe(15);
  });

  it('test_el_quinto_fallo_consecutivo_bloquea_la_cuenta_con_423', async () => {
    userModel.findByIdentifier.mockResolvedValue(registro({ failedLoginAttempts: 4 }));
    userModel.registerFailedAttempt.mockResolvedValue({ locked: true, lockSecondsLeft: 900 });

    await expect(login('ana', 'Incorrecta1')).rejects.toMatchObject({
      status: 423,
      code: 'ACCOUNT_LOCKED',
      details: { retryAfterSeconds: 900 },
    });
    expect(userModel.registerFailedAttempt).toHaveBeenCalledWith(1, MAX_FAILED_ATTEMPTS, LOCK_MINUTES);
  });

  it('test_un_fallo_antes_del_limite_responde_401_generico', async () => {
    userModel.findByIdentifier.mockResolvedValue(registro({ failedLoginAttempts: 1 }));
    userModel.registerFailedAttempt.mockResolvedValue({ locked: false, lockSecondsLeft: 0 });

    await expect(login('ana', 'Incorrecta1')).rejects.toMatchObject({ status: 401, code: 'INVALID_CREDENTIALS' });
  });

  it('test_una_cuenta_bloqueada_no_valida_la_contrasena_ni_suma_fallos', async () => {
    userModel.findByIdentifier.mockResolvedValue(registro({ isLocked: true, lockSecondsLeft: 600 }));

    await expect(login('ana', 'Correcta2026')).rejects.toMatchObject({ status: 423 });
    expect(userModel.registerFailedAttempt).not.toHaveBeenCalled();
  });

  it('test_un_acceso_correcto_con_fallos_previos_reinicia_el_contador', async () => {
    userModel.findByIdentifier.mockResolvedValue(registro({ failedLoginAttempts: 3 }));

    const result = await login('ana', 'Correcta2026');

    expect(userModel.resetFailures).toHaveBeenCalledWith(1);
    expect(result.user).toEqual({ id: 1, username: 'ana', name: 'Ana', email: 'ana@x.local', role: 'ADMIN' });
    expect(result.expiresIn).toBe(28800);
  });

  it('test_un_acceso_correcto_sin_fallos_previos_no_escribe_en_la_base', async () => {
    userModel.findByIdentifier.mockResolvedValue(registro());

    await login('ana', 'Correcta2026');

    expect(userModel.resetFailures).not.toHaveBeenCalled();
  });
});
