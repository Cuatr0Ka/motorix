import { describe, expect, it } from '@jest/globals';
import { formatFolio, parseFolioSearch } from '../../utils/orderFolio.js';

describe('folio de la orden', () => {
  it('test_formatea_el_folio_con_ceros_a_la_izquierda', () => {
    expect(formatFolio(1)).toBe('OS-000001');
    expect(formatFolio(12)).toBe('OS-000012');
    expect(formatFolio(123456)).toBe('OS-123456');
  });

  it('test_lee_el_folio_en_sus_distintas_formas', () => {
    expect(parseFolioSearch('OS-12')).toBe(12);
    expect(parseFolioSearch('os-000012')).toBe(12);
    expect(parseFolioSearch('OS12')).toBe(12);
    expect(parseFolioSearch(' 12 ')).toBe(12);
  });

  it('test_rechaza_texto_que_no_es_un_folio', () => {
    expect(parseFolioSearch('Carlos')).toBeNull();
    expect(parseFolioSearch('OS-')).toBeNull();
    expect(parseFolioSearch('0')).toBeNull();
    expect(parseFolioSearch('12abc')).toBeNull();
    expect(parseFolioSearch(undefined)).toBeNull();
  });
});
