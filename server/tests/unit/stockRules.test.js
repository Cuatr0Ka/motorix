import { describe, expect, it } from '@jest/globals';
import { assertServiceMileage } from '../../services/mileageRule.js';
import {
  assertPositiveInteger,
  assertStockAvailable,
  computeAdjustmentDelta,
  signedQuantity,
} from '../../services/stockRules.js';

const intenta = (funcion) => {
  try {
    funcion();
    return null;
  } catch (error) {
    return error;
  }
};

describe('cantidades de movimientos y líneas (RN-8)', () => {
  it('test_acepta_enteros_positivos_hasta_100000', () => {
    expect(assertPositiveInteger(1)).toBe(1);
    expect(assertPositiveInteger(100000)).toBe(100000);
  });

  it.each([0, -1, 1.5, '3', null, undefined, NaN, 100001])('test_rechaza_la_cantidad_%p', (valor) => {
    const error = intenta(() => assertPositiveInteger(valor));

    expect(error.status).toBe(400);
    expect(error.code).toBe('VALIDATION_ERROR');
  });
});

describe('ajuste por conteo físico', () => {
  it('test_la_diferencia_es_contado_menos_stock', () => {
    expect(computeAdjustmentDelta({ stock: 10, countedQuantity: 7 })).toBe(-3);
    expect(computeAdjustmentDelta({ stock: 10, countedQuantity: 12 })).toBe(2);
    expect(computeAdjustmentDelta({ stock: 4, countedQuantity: 0 })).toBe(-4);
  });

  it('test_rechaza_un_conteo_igual_al_stock_actual', () => {
    const error = intenta(() => computeAdjustmentDelta({ stock: 5, countedQuantity: 5 }));

    expect(error.status).toBe(422);
    expect(error.code).toBe('NO_ADJUSTMENT_DIFFERENCE');
  });

  it.each([-1, 2.5, '4', null, 1000001])('test_rechaza_la_cantidad_contada_%p', (valor) => {
    expect(intenta(() => computeAdjustmentDelta({ stock: 5, countedQuantity: valor })).code).toBe('VALIDATION_ERROR');
  });
});

describe('signo de los movimientos', () => {
  it('test_la_entrada_es_positiva_y_la_salida_negativa', () => {
    expect(signedQuantity('IN', 3)).toBe(3);
    expect(signedQuantity('IN', -3)).toBe(3);
    expect(signedQuantity('OUT', 3)).toBe(-3);
    expect(signedQuantity('OUT', -3)).toBe(-3);
  });

  it('test_el_ajuste_conserva_su_signo', () => {
    expect(signedQuantity('ADJUSTMENT', -2)).toBe(-2);
    expect(signedQuantity('ADJUSTMENT', 2)).toBe(2);
  });
});

describe('disponibilidad de stock (RN-8, CA-6)', () => {
  it('test_permite_una_salida_igual_al_stock', () => {
    expect(intenta(() => assertStockAvailable({ available: 5, requested: 5 }))).toBeNull();
  });

  it('test_rechaza_una_salida_mayor_al_stock_e_informa_lo_disponible', () => {
    const error = intenta(() => assertStockAvailable({ available: 4, requested: 5 }));

    expect(error.status).toBe(409);
    expect(error.code).toBe('INSUFFICIENT_STOCK');
    expect(error.details).toEqual({ available: 4, requested: 5 });
    expect(error.message).toContain('4');
  });

  it('test_rechaza_cualquier_salida_con_stock_cero', () => {
    expect(intenta(() => assertStockAvailable({ available: 0, requested: 1 })).code).toBe('INSUFFICIENT_STOCK');
  });
});

describe('regla del kilometraje del servicio', () => {
  it('test_acepta_un_kilometraje_igual_o_mayor_al_de_entrada', () => {
    expect(assertServiceMileage({ entry: 50000, service: 50000 })).toBe(50000);
    expect(assertServiceMileage({ entry: 50000, service: 50120 })).toBe(50120);
  });

  it('test_rechaza_un_kilometraje_menor_al_de_entrada', () => {
    const error = intenta(() => assertServiceMileage({ entry: 50000, service: 49999 }));

    expect(error.status).toBe(422);
    expect(error.code).toBe('SERVICE_MILEAGE_TOO_LOW');
  });

  it.each([-1, 2000001, 1.5, '100', null])('test_rechaza_el_kilometraje_fuera_de_rango_%p', (valor) => {
    expect(intenta(() => assertServiceMileage({ entry: 0, service: valor })).code).toBe('VALIDATION_ERROR');
  });
});
