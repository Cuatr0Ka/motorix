import { describe, expect, it } from '@jest/globals';
import { AppError } from '../../utils/AppError.js';
import { ORDER_STATUSES, allowedNext, assertTransition } from '../../services/orderTransitions.js';

// Única fuente de verdad de la prueba: las 7 transiciones de data-model.md.
const PERMITIDAS = new Set([
  'RECIBIDO>DIAGNOSTICO',
  'DIAGNOSTICO>EN_REPARACION',
  'DIAGNOSTICO>ESPERANDO_REFACCION',
  'EN_REPARACION>TERMINADO',
  'EN_REPARACION>ESPERANDO_REFACCION',
  'ESPERANDO_REFACCION>EN_REPARACION',
  'TERMINADO>ENTREGADO',
]);

describe('transiciones de estado de la orden (CA-5, CA-8, SC-004)', () => {
  it('test_define_los_seis_estados_del_flujo', () => {
    expect(ORDER_STATUSES).toEqual([
      'RECIBIDO',
      'DIAGNOSTICO',
      'EN_REPARACION',
      'ESPERANDO_REFACCION',
      'TERMINADO',
      'ENTREGADO',
    ]);
  });

  describe('matriz completa de 6 x 6 pares', () => {
    for (const from of ORDER_STATUSES) {
      for (const to of ORDER_STATUSES) {
        const permitida = PERMITIDAS.has(`${from}>${to}`);
        it(`test_${from}_a_${to}_${permitida ? 'se_acepta' : 'se_rechaza'}`, () => {
          if (permitida) {
            expect(() => assertTransition(from, to)).not.toThrow();
            expect(allowedNext(from)).toContain(to);
          } else {
            expect(() => assertTransition(from, to)).toThrow(AppError);
            expect(allowedNext(from)).not.toContain(to);
          }
        });
      }
    }
  });

  it('test_el_error_indica_las_transiciones_permitidas_y_el_estado_actual', () => {
    let error;
    try {
      assertTransition('RECIBIDO', 'TERMINADO');
    } catch (e) {
      error = e;
    }
    expect(error.status).toBe(422);
    expect(error.code).toBe('INVALID_TRANSITION');
    expect(error.details).toEqual({ currentStatus: 'RECIBIDO', allowed: ['DIAGNOSTICO'] });
  });

  it('test_entregado_no_tiene_salidas', () => {
    expect(allowedNext('ENTREGADO')).toEqual([]);
    expect(() => assertTransition('ENTREGADO', 'TERMINADO')).toThrow(/ya no admite cambios/);
  });

  it('test_esperando_refaccion_solo_regresa_a_en_reparacion', () => {
    expect(allowedNext('ESPERANDO_REFACCION')).toEqual(['EN_REPARACION']);
  });

  it('test_no_hay_retrocesos', () => {
    const orden = ORDER_STATUSES;
    for (const from of orden) {
      for (const to of allowedNext(from)) {
        if (from === 'ESPERANDO_REFACCION' || to === 'ESPERANDO_REFACCION') continue;
        expect(orden.indexOf(to)).toBeGreaterThan(orden.indexOf(from));
      }
    }
  });

  it('test_un_estado_desconocido_no_tiene_transiciones', () => {
    expect(allowedNext('INVENTADO')).toEqual([]);
    expect(() => assertTransition('INVENTADO', 'RECIBIDO')).toThrow(AppError);
  });
});
