import { describe, expect, it } from '@jest/globals';
import { PASSWORD_MIN_LENGTH, checkPasswordPolicy } from '../../utils/passwordPolicy.js';

describe('política de contraseñas de 10 caracteres (US10, FR-013)', () => {
  it('test_el_minimo_es_10', () => {
    expect(PASSWORD_MIN_LENGTH).toBe(10);
  });

  it('test_una_contrasena_de_10_con_mayuscula_minuscula_y_numero_es_valida', () => {
    expect(checkPasswordPolicy('Abcdefgh12')).toBeNull();
    expect(checkPasswordPolicy('Contraseña2026')).toBeNull();
  });

  it.each([
    ['Abcdefg12', 'al menos 10 caracteres'],
    ['abcdefghi1j', 'mayúscula'],
    ['ABCDEFGHI1J', 'minúscula'],
    ['Abcdefghijk', 'número'],
    ['', 'al menos 10 caracteres'],
  ])('test_rechaza_%s_con_el_mensaje_de_lo_que_falta', (password, parte) => {
    expect(checkPasswordPolicy(password)).toContain(parte);
  });

  it('test_rechaza_valores_que_no_son_texto', () => {
    expect(checkPasswordPolicy(undefined)).toContain('10 caracteres');
    expect(checkPasswordPolicy(1234567890)).toContain('10 caracteres');
  });
});
