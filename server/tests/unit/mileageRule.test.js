import { describe, expect, it } from '@jest/globals';
import { assertEntryMileage } from '../../services/mileageRule.js';

const intenta = (datos) => {
  try {
    return assertEntryMileage(datos);
  } catch (error) {
    return error;
  }
};

describe('regla de kilometraje de entrada (RN-3, RN-4, CA-6)', () => {
  it('test_acepta_un_kilometraje_mayor_o_igual_al_actual', () => {
    expect(assertEntryMileage({ previous: 50000, entry: 50001 })).toEqual({ correctionApplied: false, reason: null });
    expect(assertEntryMileage({ previous: 50000, entry: 50000 })).toEqual({ correctionApplied: false, reason: null });
  });

  it('test_rechaza_un_kilometraje_menor_sin_correccion_explicita', () => {
    const error = intenta({ previous: 50000, entry: 49999 });

    expect(error.status).toBe(422);
    expect(error.code).toBe('MILEAGE_DECREASE');
    expect(error.message).toContain('49999');
    expect(error.message).toContain('50000');
  });

  it('test_acepta_un_kilometraje_menor_con_correccion_y_motivo', () => {
    expect(assertEntryMileage({ previous: 50000, entry: 40000, correction: true, reason: '  Tablero reemplazado  ' })).toEqual({
      correctionApplied: true,
      reason: 'Tablero reemplazado',
    });
  });

  it('test_rechaza_la_correccion_sin_motivo_o_con_motivo_corto', () => {
    for (const reason of [undefined, null, '', '   ', 'abc']) {
      const error = intenta({ previous: 50000, entry: 40000, correction: true, reason });
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.details[0].field).toBe('mileageCorrectionReason');
    }
  });

  it('test_acepta_cualquier_valor_valido_si_el_vehiculo_no_tiene_kilometraje_previo', () => {
    for (const previous of [null, undefined]) {
      expect(assertEntryMileage({ previous, entry: 0 }).correctionApplied).toBe(false);
      expect(assertEntryMileage({ previous, entry: 2000000 }).correctionApplied).toBe(false);
    }
  });

  it('test_rechaza_valores_fuera_de_rango_o_no_enteros', () => {
    for (const entry of [-1, 2000001, 10.5, Number.NaN, '100']) {
      const error = intenta({ previous: null, entry });
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.details[0].field).toBe('entryMileage');
    }
  });

  it('test_una_correccion_marcada_sin_necesitarla_no_se_registra_como_correccion', () => {
    expect(assertEntryMileage({ previous: 1000, entry: 2000, correction: true, reason: 'No era necesaria' })).toEqual({
      correctionApplied: false,
      reason: null,
    });
  });
});
