import { describe, expect, it } from '@jest/globals';
import { createPartSchema, updatePartSchema } from '../../validators/partValidators.js';

const base = { code: 'FIL-ACE', name: 'Filtro de aceite', unit: 'pieza', minStock: 3, initialStock: 10 };

const alta = (extra) => createPartSchema.safeParse({ ...base, ...extra });
const edicion = (cuerpo) => updatePartSchema.safeParse(cuerpo);
const campos = (resultado) => resultado.error.issues.map((issue) => issue.path.join('.'));
const mensajes = (resultado) => resultado.error.issues.map((issue) => issue.message);

describe('precios de una refacción (FR-002)', () => {
  it('test_acepta_precios_validos_como_numero_o_cadena_y_los_normaliza_a_dos_decimales', () => {
    const resultado = alta({ purchasePrice: 120, salePrice: '180.5' });

    expect(resultado.success).toBe(true);
    expect(resultado.data.purchasePrice).toBe('120.00');
    expect(resultado.data.salePrice).toBe('180.50');
  });

  it('test_los_precios_son_opcionales_al_dar_de_alta', () => {
    const resultado = alta({});

    expect(resultado.success).toBe(true);
    expect(resultado.data.salePrice).toBeUndefined();
    expect(resultado.data.purchasePrice).toBeUndefined();
  });

  it.each([
    ['purchasePrice', -1],
    ['purchasePrice', '-0.01'],
    ['salePrice', -5],
    ['purchasePrice', 'abc'],
    ['salePrice', '12,50'],
    ['salePrice', 10.123],
    ['purchasePrice', '1.234'],
    ['salePrice', 10000000],
    ['purchasePrice', '9999999.995'],
    ['salePrice', 0.1 + 0.2],
    ['salePrice', Number.NaN],
    ['salePrice', true],
  ])('test_rechaza_el_precio_%s_con_el_valor_%p', (campo, valor) => {
    const resultado = alta({ [campo]: valor });

    expect(resultado.success).toBe(false);
    expect(campos(resultado)).toContain(campo);
  });

  it('test_acepta_el_precio_maximo_de_9999999_99_y_rechaza_un_centavo_mas', () => {
    expect(alta({ salePrice: '9999999.99' }).success).toBe(true);
    expect(alta({ salePrice: '10000000.00' }).success).toBe(false);
  });

  it('test_el_precio_de_venta_igual_a_cero_se_rechaza_y_el_de_compra_puede_ser_cero', () => {
    const venta = alta({ salePrice: 0 });
    const compra = alta({ purchasePrice: 0 });

    expect(venta.success).toBe(false);
    expect(mensajes(venta).join(' ')).toContain('mayor a cero');
    expect(compra.success).toBe(true);
    expect(compra.data.purchasePrice).toBe('0.00');
  });

  it('test_los_mensajes_de_error_estan_en_espanol_y_nombran_el_campo', () => {
    const resultado = alta({ salePrice: '10.123' });

    expect(mensajes(resultado).join(' ')).toContain('dos decimales');
  });
});

describe('categoría y marca (FR-001)', () => {
  it('test_acepta_60_caracteres_y_rechaza_61', () => {
    expect(alta({ category: 'C'.repeat(60), brand: 'M'.repeat(60) }).success).toBe(true);

    const categoria = alta({ category: 'C'.repeat(61) });
    const marca = alta({ brand: 'M'.repeat(61) });
    expect(categoria.success).toBe(false);
    expect(campos(categoria)).toContain('category');
    expect(marca.success).toBe(false);
    expect(campos(marca)).toContain('brand');
  });

  it('test_recorta_los_espacios_y_un_texto_vacio_queda_en_null', () => {
    const resultado = alta({ category: '  Filtros  ', brand: '   ' });

    expect(resultado.data.category).toBe('Filtros');
    expect(resultado.data.brand).toBeNull();
  });
});

describe('edición parcial de precios', () => {
  it('test_el_precio_de_venta_capturado_no_acepta_null', () => {
    const resultado = edicion({ salePrice: null });

    expect(resultado.success).toBe(false);
    expect(campos(resultado)).toContain('salePrice');
  });

  it('test_el_precio_de_compra_acepta_null_para_borrar_el_dato', () => {
    const resultado = edicion({ purchasePrice: null });

    expect(resultado.success).toBe(true);
    expect(resultado.data.purchasePrice).toBeNull();
  });

  it('test_acepta_los_campos_nuevos_y_la_confirmacion_en_una_edicion_parcial', () => {
    const resultado = edicion({ category: 'Frenos', brand: 'Brembo', salePrice: 90, confirmBelowCost: true });

    expect(resultado.success).toBe(true);
    expect(resultado.data).toMatchObject({ category: 'Frenos', brand: 'Brembo', salePrice: '90.00', confirmBelowCost: true });
  });

  it('test_rechaza_una_confirmacion_que_no_es_booleana', () => {
    expect(edicion({ confirmBelowCost: 'si' }).success).toBe(false);
    expect(alta({ confirmBelowCost: 1 }).success).toBe(false);
  });

  it('test_sigue_rechazando_campos_que_no_se_pueden_editar_como_el_codigo_o_el_stock', () => {
    expect(edicion({ code: 'OTRO' }).success).toBe(false);
    expect(edicion({ stock: 5 }).success).toBe(false);
  });

  it('test_exige_al_menos_un_campo', () => {
    expect(edicion({}).success).toBe(false);
  });
});
