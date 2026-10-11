import { describe, expect, it } from '@jest/globals';
import { getMaintenanceConfig } from '../../config/env.js';
import { assertMaintenanceTarget, computeIndicator } from '../../services/maintenanceStatus.js';

const HOY = '2026-10-11';

const indicador = (datos) => computeIndicator({ today: HOY, warnDays: 30, warnKm: 1000, ...datos });

const intenta = (datos) => {
  try {
    assertMaintenanceTarget({ today: HOY, ...datos });
    return null;
  } catch (error) {
    return error;
  }
};

describe('indicador del mantenimiento (RN-11, RN-12, CA-3)', () => {
  it('test_es_vencido_si_la_fecha_objetivo_ya_paso', () => {
    expect(indicador({ dueDate: '2026-10-10', dueMileage: null, currentMileage: 1000 })).toBe('VENCIDO');
  });

  it('test_es_vencido_si_el_kilometraje_actual_alcanzo_el_objetivo', () => {
    expect(indicador({ dueDate: null, dueMileage: 50000, currentMileage: 50000 })).toBe('VENCIDO');
    expect(indicador({ dueDate: null, dueMileage: 50000, currentMileage: 52000 })).toBe('VENCIDO');
  });

  it('test_es_vencido_si_basta_una_de_las_dos_condiciones', () => {
    expect(indicador({ dueDate: '2027-12-01', dueMileage: 50000, currentMileage: 50001 })).toBe('VENCIDO');
    expect(indicador({ dueDate: '2026-10-01', dueMileage: 90000, currentMileage: 10000 })).toBe('VENCIDO');
  });

  it('test_es_proximo_en_el_limite_exacto_de_30_dias', () => {
    expect(indicador({ dueDate: '2026-11-10', dueMileage: null, currentMileage: 0 })).toBe('PROXIMO');
    expect(indicador({ dueDate: '2026-11-11', dueMileage: null, currentMileage: 0 })).toBe('NORMAL');
  });

  it('test_es_proximo_en_el_limite_exacto_de_1000_km', () => {
    expect(indicador({ dueDate: null, dueMileage: 51000, currentMileage: 50000 })).toBe('PROXIMO');
    expect(indicador({ dueDate: null, dueMileage: 51001, currentMileage: 50000 })).toBe('NORMAL');
  });

  it('test_una_fecha_igual_a_hoy_es_proxima_y_no_vencida', () => {
    expect(indicador({ dueDate: HOY, dueMileage: null, currentMileage: null })).toBe('PROXIMO');
  });

  it('test_es_proximo_si_solo_una_condicion_esta_dentro_del_margen', () => {
    expect(indicador({ dueDate: '2027-06-01', dueMileage: 50500, currentMileage: 50000 })).toBe('PROXIMO');
    expect(indicador({ dueDate: '2026-10-20', dueMileage: 90000, currentMileage: 10000 })).toBe('PROXIMO');
  });

  it('test_es_normal_si_ninguna_condicion_esta_cerca', () => {
    expect(indicador({ dueDate: '2027-04-01', dueMileage: 60000, currentMileage: 50000 })).toBe('NORMAL');
  });

  it('test_un_mantenimiento_solo_por_fecha_ignora_el_kilometraje', () => {
    expect(indicador({ dueDate: '2027-04-01', dueMileage: null, currentMileage: 9999999 })).toBe('NORMAL');
  });

  it('test_un_mantenimiento_solo_por_kilometraje_ignora_la_fecha', () => {
    expect(indicador({ dueDate: null, dueMileage: 60000, currentMileage: 50000 })).toBe('NORMAL');
  });

  it('test_un_vehiculo_sin_kilometraje_omite_la_condicion_por_kilometraje', () => {
    expect(indicador({ dueDate: '2027-04-01', dueMileage: 100, currentMileage: null })).toBe('NORMAL');
    expect(indicador({ dueDate: null, dueMileage: 100, currentMileage: null })).toBe('NORMAL');
  });

  it('test_respeta_margenes_personalizados', () => {
    const base = { dueDate: '2026-10-25', dueMileage: null, currentMileage: 0 };
    expect(indicador({ ...base, warnDays: 7 })).toBe('NORMAL');
    expect(indicador({ ...base, warnDays: 14 })).toBe('PROXIMO');
    expect(indicador({ dueDate: null, dueMileage: 5000, currentMileage: 0, warnKm: 5000 })).toBe('PROXIMO');
  });

  it('test_acepta_fechas_como_objeto_date', () => {
    expect(indicador({ dueDate: new Date(2026, 9, 10), dueMileage: null, currentMileage: 0 })).toBe('VENCIDO');
    expect(computeIndicator({ today: new Date(2026, 9, 11, 23, 59), dueDate: new Date(2026, 9, 11), warnDays: 0 })).toBe('PROXIMO');
  });
});

describe('validación del objetivo del mantenimiento (RN-11)', () => {
  it('test_rechaza_un_mantenimiento_sin_fecha_ni_kilometraje', () => {
    const error = intenta({ dueDate: null, dueMileage: null, currentMileage: 100 });

    expect(error.status).toBe(422);
    expect(error.code).toBe('MAINTENANCE_TARGET_REQUIRED');
  });

  it('test_rechaza_una_fecha_anterior_a_hoy_y_acepta_la_de_hoy', () => {
    expect(intenta({ dueDate: '2026-10-10', dueMileage: null, currentMileage: 100 }).code).toBe('MAINTENANCE_DATE_IN_PAST');
    expect(intenta({ dueDate: HOY, dueMileage: null, currentMileage: 100 })).toBeNull();
  });

  it('test_rechaza_un_kilometraje_menor_o_igual_al_actual', () => {
    expect(intenta({ dueDate: null, dueMileage: 100, currentMileage: 100 }).code).toBe('MAINTENANCE_MILEAGE_TOO_LOW');
    expect(intenta({ dueDate: null, dueMileage: 99, currentMileage: 100 }).code).toBe('MAINTENANCE_MILEAGE_TOO_LOW');
    expect(intenta({ dueDate: null, dueMileage: 101, currentMileage: 100 })).toBeNull();
  });

  it('test_acepta_cualquier_kilometraje_si_el_vehiculo_no_tiene_uno_previo', () => {
    expect(intenta({ dueDate: null, dueMileage: 5000, currentMileage: null })).toBeNull();
  });

  it('test_rechaza_un_kilometraje_fuera_de_rango', () => {
    expect(intenta({ dueDate: null, dueMileage: 2000001, currentMileage: 0 }).status).toBe(400);
    expect(intenta({ dueDate: null, dueMileage: 10.5, currentMileage: 0 }).status).toBe(400);
  });
});

describe('márgenes de aviso configurables (RN-12)', () => {
  it('test_usa_30_dias_y_1000_km_por_defecto', () => {
    expect(getMaintenanceConfig({})).toEqual({ warnDays: 30, warnKm: 1000 });
  });

  it('test_lee_los_margenes_del_entorno', () => {
    expect(getMaintenanceConfig({ MAINTENANCE_WARN_DAYS: '15', MAINTENANCE_WARN_KM: '500' })).toEqual({ warnDays: 15, warnKm: 500 });
  });

  it('test_rechaza_valores_que_no_son_enteros_positivos', () => {
    expect(() => getMaintenanceConfig({ MAINTENANCE_WARN_DAYS: 'abc' })).toThrow('MAINTENANCE_WARN_DAYS');
    expect(() => getMaintenanceConfig({ MAINTENANCE_WARN_KM: '0' })).toThrow('MAINTENANCE_WARN_KM');
  });
});
