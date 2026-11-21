import { describe, expect, it } from '@jest/globals';
import { MAX_RANGE_DAYS, fromCents, parseRange, presetRange, toCents } from '../../services/reportRules.js';

const falla = (entrada) => {
  try {
    parseRange(entrada);
  } catch (error) {
    return error;
  }
  return null;
};

describe('periodo de un reporte (US4, FR-019)', () => {
  it('test_acepta_fechas_reales_y_calcula_los_extremos_con_el_dia_siguiente_a_to', () => {
    const rango = parseRange({ from: '2026-10-01', to: '2026-10-31' });

    expect(rango).toMatchObject({ from: '2026-10-01', to: '2026-10-31', days: 31, startSql: '2026-10-01 00:00:00', endSql: '2026-11-01 00:00:00' });
  });

  it('test_un_solo_dia_y_el_cambio_de_anio_son_validos', () => {
    expect(parseRange({ from: '2026-12-31', to: '2026-12-31' })).toMatchObject({ days: 1, endSql: '2027-01-01 00:00:00' });
  });

  it.each([
    ['2026-02-30', '2026-03-05'],
    ['2026-13-01', '2026-13-02'],
    ['ayer', '2026-03-05'],
    ['2026-3-5', '2026-03-05'],
    ['', '2026-03-05'],
    [undefined, '2026-03-05'],
    ['2026-03-05', '2026-02-31'],
  ])('test_rechaza_las_fechas_invalidas_%s_%s', (from, to) => {
    const error = falla({ from, to });

    expect(error?.code).toBe('VALIDATION_ERROR');
  });

  it('test_rechaza_to_anterior_a_from', () => {
    expect(falla({ from: '2026-10-10', to: '2026-10-09' })?.code).toBe('VALIDATION_ERROR');
  });

  it('test_acepta_366_dias_y_rechaza_367_con_el_limite_en_details', () => {
    expect(parseRange({ from: '2026-01-01', to: '2027-01-01' }).days).toBe(MAX_RANGE_DAYS);
    const error = falla({ from: '2026-01-01', to: '2027-01-02' });

    expect(error.code).toBe('VALIDATION_ERROR');
    expect(error.details[0].limit).toBe(366);
  });

  it('test_los_periodos_rapidos_hoy_semana_y_mes', () => {
    const miercoles = new Date(2026, 10, 18, 15, 30); // 18/11/2026 es miércoles

    expect(presetRange('today', miercoles)).toEqual({ from: '2026-11-18', to: '2026-11-18' });
    expect(presetRange('week', miercoles)).toEqual({ from: '2026-11-16', to: '2026-11-18' });
    expect(presetRange('month', miercoles)).toEqual({ from: '2026-11-01', to: '2026-11-18' });
    expect(presetRange('week', new Date(2026, 10, 16))).toEqual({ from: '2026-11-16', to: '2026-11-16' }); // lunes
    expect(presetRange('week', new Date(2026, 10, 22))).toEqual({ from: '2026-11-16', to: '2026-11-22' }); // domingo
  });
});

describe('centavos enteros (FR-019)', () => {
  it('test_convierte_sin_errores_de_redondeo', () => {
    expect(toCents('0.10') + toCents('0.20')).toBe(30);
    expect(toCents('1234.56')).toBe(123456);
    expect(toCents(19.99)).toBe(1999);
    expect(fromCents(30)).toBe('0.30');
    expect(fromCents(123456)).toBe('1234.56');
    expect(fromCents(0)).toBe('0.00');
  });
});
