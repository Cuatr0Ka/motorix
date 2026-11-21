import { describe, expect, it } from '@jest/globals';
import { suggestNextMaintenance } from '../../services/serviceIntervals.js';

const hoy = new Date(2026, 10, 21); // 21/11/2026 (hora local)

describe('suggestNextMaintenance (US3, FR-005 a FR-007)', () => {
  it('test_con_un_solo_tipo_propone_hoy_mas_los_dias_y_el_kilometraje_del_servicio_mas_los_km', () => {
    const resultado = suggestNextMaintenance({
      serviceTypes: [{ id: 1, name: 'Cambio de aceite', intervalDays: 180, intervalKm: 5000 }],
      today: hoy,
      serviceMileage: 50000,
      currentMileage: 49000,
    });

    expect(resultado).toEqual({ dueDate: '2027-05-20', dueMileage: 55000, basedOn: [{ serviceTypeId: 1, name: 'Cambio de aceite' }] });
  });

  it('test_con_varios_tipos_toma_el_intervalo_mas_corto_de_cada_eje', () => {
    const resultado = suggestNextMaintenance({
      serviceTypes: [
        { id: 1, name: 'Aceite', intervalDays: 180, intervalKm: 5000 },
        { id: 2, name: 'Frenos', intervalDays: 90, intervalKm: 20000 },
      ],
      today: hoy,
      serviceMileage: 10000,
      currentMileage: 10000,
    });

    expect(resultado.dueDate).toBe('2027-02-19'); // 90 días
    expect(resultado.dueMileage).toBe(15000); // 5 000 km
    expect(resultado.basedOn.map((t) => t.serviceTypeId)).toEqual([1, 2]);
  });

  it('test_un_tipo_con_solo_dias_no_propone_kilometraje', () => {
    const resultado = suggestNextMaintenance({
      serviceTypes: [{ id: 1, name: 'Revisión', intervalDays: 30, intervalKm: null }],
      today: hoy,
      serviceMileage: 1000,
      currentMileage: 1000,
    });

    expect(resultado.dueDate).toBe('2026-12-21');
    expect(resultado.dueMileage).toBeNull();
  });

  it('test_un_tipo_con_solo_kilometros_no_propone_fecha', () => {
    const resultado = suggestNextMaintenance({
      serviceTypes: [{ id: 1, name: 'Revisión', intervalDays: null, intervalKm: 3000 }],
      today: hoy,
      serviceMileage: 1000,
      currentMileage: 1000,
    });

    expect(resultado.dueDate).toBeNull();
    expect(resultado.dueMileage).toBe(4000);
  });

  it('test_sin_tipos_con_intervalo_devuelve_null', () => {
    expect(suggestNextMaintenance({ serviceTypes: [], today: hoy, serviceMileage: 1, currentMileage: 1 })).toBeNull();
    expect(
      suggestNextMaintenance({
        serviceTypes: [{ id: 1, name: 'Sin intervalo', intervalDays: null, intervalKm: null }],
        today: hoy,
        serviceMileage: 1,
        currentMileage: 1,
      }),
    ).toBeNull();
  });

  it('test_usa_el_kilometraje_actual_del_vehiculo_si_no_hay_kilometraje_del_servicio', () => {
    const resultado = suggestNextMaintenance({
      serviceTypes: [{ id: 1, name: 'Aceite', intervalDays: null, intervalKm: 5000 }],
      today: hoy,
      serviceMileage: null,
      currentMileage: 42000,
    });

    expect(resultado.dueMileage).toBe(47000);
  });

  it('test_no_repite_un_tipo_que_aparece_en_varias_lineas', () => {
    const tipo = { id: 1, name: 'Aceite', intervalDays: 100, intervalKm: null };
    const resultado = suggestNextMaintenance({ serviceTypes: [tipo, tipo], today: hoy, serviceMileage: 0, currentMileage: 0 });

    expect(resultado.basedOn).toHaveLength(1);
  });
});
