import { describe, expect, it } from '@jest/globals';
import {
  assertAmountMatches,
  assertOrderPayable,
  assertSafeReference,
  assertTransition,
  formatCents,
  initialStatusFor,
  mapProviderStatus,
  toCents,
} from '../../services/paymentRules.js';

const intenta = (funcion) => {
  try {
    funcion();
    return null;
  } catch (error) {
    return error;
  }
};

describe('estado inicial del pago por método (FR-003, FR-004)', () => {
  it.each(['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'])('test_el_metodo_%s_nace_pagado', (metodo) => {
    expect(initialStatusFor(metodo)).toBe('PAGADO');
  });

  it('test_mercado_pago_nace_pendiente', () => {
    expect(initialStatusFor('MERCADO_PAGO')).toBe('PENDIENTE');
  });

  it.each(['CHEQUE', '', null, undefined, 'efectivo'])('test_rechaza_el_metodo_%p', (metodo) => {
    const error = intenta(() => initialStatusFor(metodo));

    expect(error.status).toBe(400);
    expect(error.code).toBe('VALIDATION_ERROR');
  });
});

describe('transiciones de estado del pago', () => {
  const estados = ['PENDIENTE', 'PAGADO', 'RECHAZADO', 'CANCELADO'];

  it.each([['PENDIENTE', 'PAGADO'], ['PENDIENTE', 'RECHAZADO'], ['PENDIENTE', 'CANCELADO']])(
    'test_permite_pasar_de_%s_a_%s',
    (desde, hacia) => {
      expect(intenta(() => assertTransition(desde, hacia))).toBeNull();
    },
  );

  const invalidas = estados.flatMap((desde) => estados.map((hacia) => [desde, hacia])).filter(([d]) => d !== 'PENDIENTE');

  it.each(invalidas)('test_rechaza_pasar_de_%s_a_%s', (desde, hacia) => {
    const error = intenta(() => assertTransition(desde, hacia));

    expect(error.status).toBe(409);
    expect(error.code).toBe(hacia === 'CANCELADO' ? 'PAYMENT_NOT_CANCELLABLE' : 'PAYMENT_NOT_PENDING');
  });

  it('test_pendiente_a_pendiente_no_es_una_transicion', () => {
    expect(intenta(() => assertTransition('PENDIENTE', 'PENDIENTE')).code).toBe('PAYMENT_NOT_PENDING');
  });
});

describe('orden cobrable (FR-006)', () => {
  it.each(['TERMINADO', 'ENTREGADO'])('test_acepta_una_orden_%s_con_total', (estado) => {
    expect(intenta(() => assertOrderPayable({ status: estado, totalCents: 125000 }))).toBeNull();
  });

  it.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])('test_rechaza_una_orden_%s', (estado) => {
    const error = intenta(() => assertOrderPayable({ status: estado, totalCents: 125000 }));

    expect(error.status).toBe(409);
    expect(error.code).toBe('ORDER_NOT_PAYABLE');
  });

  it.each([0, -100, null, undefined, 12.5])('test_rechaza_el_total_%p', (total) => {
    const error = intenta(() => assertOrderPayable({ status: 'TERMINADO', totalCents: total }));

    expect(error.status).toBe(422);
    expect(error.code).toBe('NOTHING_TO_CHARGE');
  });
});

describe('importe contra el total vigente', () => {
  it('test_acepta_el_importe_igual_o_ausente', () => {
    expect(intenta(() => assertAmountMatches({ amountCents: 125000, totalCents: 125000 }))).toBeNull();
    expect(intenta(() => assertAmountMatches({ amountCents: undefined, totalCents: 125000 }))).toBeNull();
    expect(intenta(() => assertAmountMatches({ amountCents: null, totalCents: 125000 }))).toBeNull();
  });

  it('test_rechaza_un_importe_distinto_e_informa_el_total', () => {
    const error = intenta(() => assertAmountMatches({ amountCents: 100000, totalCents: 125000 }));

    expect(error.status).toBe(422);
    expect(error.code).toBe('AMOUNT_MISMATCH');
    expect(error.details).toEqual({ total: '1250.00' });
    expect(error.message).toContain('1250.00');
  });

  it('test_convierte_importes_a_centavos_sin_errores_de_redondeo', () => {
    expect(toCents('1250.00')).toBe(125000);
    expect(toCents(0.1 + 0.2)).toBe(30);
    expect(toCents('19.99')).toBe(1999);
    expect(formatCents(1999)).toBe('19.99');
    expect(formatCents(0)).toBe('0.00');
  });
});

describe('referencia segura (RN-14)', () => {
  it.each([undefined, null, '', 'TERM-48213', 'Clave de rastreo MBAN01002210110012', 'Folio 123', '12345678901'])(
    'test_acepta_la_referencia_%p',
    (texto) => {
      expect(intenta(() => assertSafeReference(texto))).toBeNull();
    },
  );

  it('test_acepta_exactamente_100_caracteres_y_rechaza_101', () => {
    expect(intenta(() => assertSafeReference('A'.repeat(100)))).toBeNull();
    expect(intenta(() => assertSafeReference('A'.repeat(101))).status).toBe(400);
  });

  it.each([
    '4111111111111111',
    '4111 1111 1111 1111',
    '4111-1111-1111-1111',
    'tarjeta 5555555555554444 ok',
    '4012888888881881',
    '6011-1111-1111-1117',
    '378282246310005',
  ])('test_rechaza_la_referencia_con_numero_de_tarjeta_valido_%s', (texto) => {
    const error = intenta(() => assertSafeReference(texto));

    expect(error.status).toBe(400);
    expect(error.details[0].field).toBe('reference');
    expect(error.details[0].message).toContain('número de tarjeta');
  });

  it('test_una_cifra_de_20_o_mas_digitos_no_se_confunde_con_una_tarjeta', () => {
    expect(intenta(() => assertSafeReference('12345678901234567890'))).toBeNull();
  });

  it('test_rechaza_una_referencia_que_no_es_texto', () => {
    expect(intenta(() => assertSafeReference(1234)).status).toBe(400);
  });
});

describe('referencias largas que no son tarjetas', () => {
  it.each(['1234567890123', '1234567890123456789', 'MBAN01002210110012', '1234567890123450'])('test_acepta_la_cifra_larga_%s_que_no_cumple_luhn', (texto) => {
    expect(intenta(() => assertSafeReference(texto))).toBeNull();
  });
});

describe('estado según el proveedor', () => {
  it('test_una_operacion_aprobada_deja_el_pago_pagado', () => {
    const resultado = mapProviderStatus([{ id: 10, status: 'approved' }]);

    expect(resultado.status).toBe('PAGADO');
    expect(resultado.operation.id).toBe(10);
  });

  it.each(['rejected', 'cancelled'])('test_una_operacion_%s_deja_el_pago_rechazado', (estado) => {
    expect(mapProviderStatus([{ id: 1, status: estado }]).status).toBe('RECHAZADO');
  });

  it.each(['pending', 'in_process', 'authorized', 'in_mediation', 'algo_desconocido'])('test_una_operacion_%s_sigue_pendiente', (estado) => {
    expect(mapProviderStatus([{ id: 1, status: estado }]).status).toBe('PENDIENTE');
  });

  it('test_sin_operaciones_sigue_pendiente', () => {
    expect(mapProviderStatus([])).toEqual({ status: 'PENDIENTE', operation: null });
    expect(mapProviderStatus(undefined)).toEqual({ status: 'PENDIENTE', operation: null });
    expect(mapProviderStatus(null).status).toBe('PENDIENTE');
  });

  it('test_gana_la_operacion_aprobada_aunque_haya_otras_mas_recientes', () => {
    const resultado = mapProviderStatus([
      { id: 3, status: 'rejected' },
      { id: 2, status: 'approved' },
      { id: 1, status: 'rejected' },
    ]);

    expect(resultado.status).toBe('PAGADO');
    expect(resultado.operation.id).toBe(2);
  });

  it('test_sin_aprobada_gana_la_mas_reciente', () => {
    expect(mapProviderStatus([{ id: 3, status: 'pending' }, { id: 2, status: 'rejected' }]).status).toBe('PENDIENTE');
    expect(mapProviderStatus([{ id: 3, status: 'rejected' }, { id: 2, status: 'pending' }]).status).toBe('RECHAZADO');
  });
});
