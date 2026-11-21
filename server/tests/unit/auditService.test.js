import { afterEach, beforeEach, describe, expect, it, jest } from '@jest/globals';

// El modelo se sustituye por un doble: estas pruebas no necesitan la base de datos.
const insert = jest.fn();
jest.unstable_mockModule('../../models/auditLogModel.js', () => ({ insert, list: jest.fn() }));

const { ACTIONS, isSafeSummary, record } = await import('../../services/auditService.js');

let consola;

beforeEach(() => {
  insert.mockReset();
  insert.mockResolvedValue(1);
  consola = jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  consola.mockRestore();
});

describe('registro de la bitácora (FR-023 a FR-025)', () => {
  it('test_registra_cada_accion_valida_con_su_usuario_y_su_resumen', async () => {
    for (const [indice, action] of Object.values(ACTIONS).entries()) {
      insert.mockClear();
      const ok = await record({ actor: { id: 7 }, action, entityType: 'user', entityId: 3, summary: `Resumen número ${indice}` });

      expect(ok).toBe(true);
      expect(insert).toHaveBeenCalledWith({
        actorUserId: 7,
        action,
        entityType: 'user',
        entityId: 3,
        summary: `Resumen número ${indice}`,
      });
    }
  });

  it('test_hay_doce_acciones_y_son_las_del_modelo_de_datos', () => {
    expect(Object.values(ACTIONS).sort()).toEqual(
      [
        'ACCOUNT_LOCKED',
        'LOGIN_FAILED',
        'PART_PRICE_CHANGED',
        'PASSWORD_CHANGED',
        'PAYMENT_CANCELLED',
        'SERVICE_TYPE_CHANGED',
        'SETTINGS_CHANGED',
        'TERMS_ACCEPTED',
        'USER_ACTIVATED',
        'USER_CREATED',
        'USER_DEACTIVATED',
        'USER_ROLE_CHANGED',
      ].sort(),
    );
  });

  it('test_una_accion_desconocida_no_se_guarda', async () => {
    const ok = await record({ actor: { id: 1 }, action: 'OTRA_COSA', summary: 'Algo' });

    expect(ok).toBe(false);
    expect(insert).not.toHaveBeenCalled();
  });

  it('test_un_resumen_con_contrasena_hash_o_token_no_se_guarda', async () => {
    const reservados = [
      'Cambió su contraseña: Secreta2026!',
      'password=Secreta2026',
      'Hash $2a$10$abcdefghijk',
      'Token eyJhbGciOiJIUzI1NiJ9.abc.def',
      'Bearer abc123',
      'Pago con tarjeta 4111 1111 1111 1111',
      'Tarjeta 4111-1111-1111-1111',
    ];
    for (const summary of reservados) {
      const ok = await record({ actor: { id: 1 }, action: ACTIONS.USER_CREATED, summary });
      expect({ summary, ok }).toEqual({ summary, ok: false });
    }
    expect(insert).not.toHaveBeenCalled();
  });

  it('test_un_resumen_normal_si_pasa_la_revision', () => {
    for (const summary of [
      'Alta de «recepcion2» con rol RECEPTIONIST',
      'Balatas delanteras: venta 780.00 → 820.00',
      'Pago de la orden OS-000012 cancelado',
      'Aceptó los términos 1.0',
    ]) {
      expect(isSafeSummary(summary)).toBe(true);
    }
    expect(isSafeSummary('')).toBe(false);
    expect(isSafeSummary('   ')).toBe(false);
    expect(isSafeSummary(null)).toBe(false);
  });

  it('test_una_falla_del_modelo_no_propaga_el_error', async () => {
    insert.mockRejectedValue(new Error('la base no responde'));

    const ok = await record({ actor: { id: 1 }, action: ACTIONS.SETTINGS_CHANGED, summary: 'Taller: nombre' });

    expect(ok).toBe(false);
    expect(consola).toHaveBeenCalled();
  });

  it('test_el_resumen_se_recorta_a_255_caracteres', async () => {
    await record({ actor: { id: 1 }, action: ACTIONS.SETTINGS_CHANGED, summary: 'a'.repeat(400) });

    expect(insert.mock.calls[0][0].summary).toHaveLength(255);
  });

  it('test_sin_actor_se_guarda_con_usuario_nulo', async () => {
    await record({ actor: null, action: ACTIONS.SETTINGS_CHANGED, summary: 'Taller: nombre' });

    expect(insert.mock.calls[0][0].actorUserId).toBeNull();
  });
});
