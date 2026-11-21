import { describe, expect, it } from '@jest/globals';
import {
  MAX_AMOUNT_CENTS,
  assertTotalWithinLimit,
  isLegacyLine,
  lineAmountCents,
  presentOrderPart,
  presentTotals,
} from '../../services/orderTotals.js';

const intenta = (funcion) => {
  try {
    funcion();
    return null;
  } catch (error) {
    return error;
  }
};

describe('importe de una línea de refacción (FR-005)', () => {
  it.each([
    [1, 1, 1],
    [2, 18000, 36000],
    [100000, 1, 100000],
    [3, 12345, 37035],
    [100000, 999999999, 99999999900000],
  ])('test_importe_de_la_linea_con_cantidad_%p_y_precio_%p_centavos', (cantidad, precio, esperado) => {
    expect(lineAmountCents(cantidad, precio)).toBe(esperado);
  });

  it('test_el_importe_siempre_es_un_entero_de_centavos_sin_fracciones', () => {
    // 3 piezas de 0.10 pesos: la suma en centavos enteros no arrastra errores de coma flotante.
    expect(lineAmountCents(3, 10)).toBe(30);
    expect(Number.isInteger(lineAmountCents(7, 1999))).toBe(true);
  });

  it.each([0, -1, 1.5, '2', null, undefined, NaN])('test_rechaza_la_cantidad_%p', (cantidad) => {
    const error = intenta(() => lineAmountCents(cantidad, 100));

    expect(error).not.toBeNull();
    expect(error.status).toBe(400);
  });

  it.each([-1, 1.5, '100', null, undefined, NaN])('test_rechaza_el_precio_%p', (precio) => {
    const error = intenta(() => lineAmountCents(1, precio));

    expect(error).not.toBeNull();
    expect(error.status).toBe(400);
  });
});

describe('línea anterior a los precios (D-03)', () => {
  it('test_un_precio_cero_es_una_linea_anterior', () => {
    expect(isLegacyLine(0)).toBe(true);
  });

  it.each([1, 100, 999999999])('test_un_precio_%p_no_es_una_linea_anterior', (precio) => {
    expect(isLegacyLine(precio)).toBe(false);
  });
});

describe('tope del total de la orden (FR-022)', () => {
  it('test_el_tope_es_9999999_99_en_centavos', () => {
    expect(MAX_AMOUNT_CENTS).toBe(999999999);
  });

  it.each([0, 1, 500000, MAX_AMOUNT_CENTS])('test_acepta_el_total_%p', (total) => {
    expect(() => assertTotalWithinLimit(total)).not.toThrow();
  });

  it('test_rechaza_un_centavo_arriba_del_tope_con_el_limite_en_los_detalles', () => {
    const error = intenta(() => assertTotalWithinLimit(MAX_AMOUNT_CENTS + 1));

    expect(error.status).toBe(422);
    expect(error.code).toBe('ORDER_TOTAL_LIMIT');
    expect(error.details).toEqual({ limit: '9999999.99' });
    expect(error.message).toContain('9 999 999.99');
  });

  it('test_rechaza_un_total_muy_superior_al_tope', () => {
    const error = intenta(() => assertTotalWithinLimit(100000 * 999999999));

    expect(error.code).toBe('ORDER_TOTAL_LIMIT');
  });
});

describe('proyección por rol de las líneas y los totales (FR-013, FR-014)', () => {
  const linea = {
    id: 5,
    partId: 9,
    code: 'FIL-ACE',
    name: 'Filtro de aceite',
    unit: 'pieza',
    quantity: 2,
    unitPrice: '180.00',
    amount: '360.00',
    legacy: false,
  };
  const totales = { services: '500.00', labor: '300.00', parts: '360.00', total: '1160.00' };

  it.each(['ADMIN', 'RECEPTIONIST'])('test_el_rol_%s_recibe_la_linea_completa_con_precio_e_importe', (rol) => {
    expect(presentOrderPart(linea, rol)).toEqual(linea);
  });

  it('test_el_mecanico_recibe_la_linea_sin_precio_ni_importe_ni_bandera', () => {
    const vista = presentOrderPart(linea, 'MECHANIC');

    expect(vista).toEqual({ id: 5, partId: 9, code: 'FIL-ACE', name: 'Filtro de aceite', unit: 'pieza', quantity: 2 });
    expect(vista).not.toHaveProperty('unitPrice');
    expect(vista).not.toHaveProperty('amount');
    expect(vista).not.toHaveProperty('legacy');
  });

  it.each(['ADMIN', 'RECEPTIONIST'])('test_el_rol_%s_recibe_los_totales_con_refacciones', (rol) => {
    expect(presentTotals(totales, rol)).toEqual(totales);
  });

  it('test_el_mecanico_recibe_servicios_mas_mano_de_obra_sin_el_campo_de_refacciones', () => {
    const vista = presentTotals(totales, 'MECHANIC');

    expect(vista).toEqual({ services: '500.00', labor: '300.00', total: '800.00' });
    expect(vista).not.toHaveProperty('parts');
  });
});
