import { describe, expect, it } from '@jest/globals';
import { createClientNoticeSchema, readNoticesSchema } from '../../validators/noticeValidators.js';

describe('validador de lectura de avisos', () => {
  it('test_acepta_de_una_a_cincuenta_claves_validas', () => {
    expect(readNoticesSchema.safeParse({ keys: ['STOCK_LOW:12'] }).success).toBe(true);
    const cincuenta = Array.from({ length: 50 }, (_, i) => `STOCK_LOW:${i + 1}`);
    expect(readNoticesSchema.safeParse({ keys: cincuenta }).success).toBe(true);
  });

  it('test_rechaza_un_arreglo_vacio_o_con_mas_de_cincuenta_claves', () => {
    expect(readNoticesSchema.safeParse({ keys: [] }).success).toBe(false);
    const cincuentaYUna = Array.from({ length: 51 }, (_, i) => `STOCK_LOW:${i + 1}`);
    expect(readNoticesSchema.safeParse({ keys: cincuentaYUna }).success).toBe(false);
  });

  it('test_rechaza_claves_mal_formadas_o_que_no_son_texto', () => {
    expect(readNoticesSchema.safeParse({ keys: ['mala'] }).success).toBe(false);
    expect(readNoticesSchema.safeParse({ keys: [12] }).success).toBe(false);
    expect(readNoticesSchema.safeParse({ keys: "STOCK_LOW:1' OR '1'='1" }).success).toBe(false);
    expect(readNoticesSchema.safeParse({}).success).toBe(false);
  });

  it('test_rechaza_campos_desconocidos', () => {
    expect(readNoticesSchema.safeParse({ keys: ['STOCK_LOW:1'], extra: 1 }).success).toBe(false);
  });
});

describe('validador del aviso a un cliente', () => {
  it('test_acepta_cada_motivo_con_un_hecho_entero_positivo', () => {
    for (const reason of ['ORDER_READY', 'APPT_TOMORROW', 'MAINT_UPCOMING', 'MAINT_OVERDUE']) {
      expect(createClientNoticeSchema.safeParse({ reason, factId: 31 }).success).toBe(true);
    }
  });

  it('test_rechaza_un_motivo_desconocido', () => {
    const resultado = createClientNoticeSchema.safeParse({ reason: 'OTRO', factId: 1 });
    expect(resultado.success).toBe(false);
    expect(resultado.error.issues[0].message).toBe('El motivo del aviso no es válido.');
  });

  it('test_rechaza_un_hecho_que_no_es_entero_positivo', () => {
    for (const factId of [0, -1, 1.5, '31', null, undefined]) {
      expect(createClientNoticeSchema.safeParse({ reason: 'ORDER_READY', factId }).success).toBe(false);
    }
  });

  it('test_rechaza_una_nota_u_otro_campo_extra', () => {
    const resultado = createClientNoticeSchema.safeParse({ reason: 'ORDER_READY', factId: 1, note: 'no contestó' });
    expect(resultado.success).toBe(false);
  });
});
