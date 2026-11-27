import { readFileSync } from 'node:fs';
import { describe, expect, it } from '@jest/globals';
import { fillShopData } from '../../services/termsService.js';

const sql = readFileSync(new URL('../../../database/migrations/008_terminos_y_aviso_de_privacidad.sql', import.meta.url), 'utf8');

describe('textos de la migración 008 (términos y aviso de privacidad)', () => {
  it('test_solo_usa_los_marcadores_que_el_servidor_sabe_reemplazar', () => {
    const marcadores = new Set((sql.match(/\{\{[^}]*\}\}/g) ?? []).filter((m) => !m.includes('Configuración')));
    // El encabezado de la migración también cita los marcadores; los tres válidos son los únicos permitidos.
    for (const marcador of marcadores) {
      expect(['{{TALLER_NOMBRE}}', '{{TALLER_DOMICILIO}}', '{{TALLER_TELEFONO}}', '{{TALLER_CORREO}}']).toContain(marcador);
    }
  });

  it('test_el_aviso_integral_incluye_los_elementos_minimos_del_articulo_15', () => {
    const aviso = sql.slice(sql.indexOf('AVISO DE PRIVACIDAD INTEGRAL'));
    for (const elemento of [
      'Quién es el responsable',
      'Qué datos personales tratamos',
      'datos personales sensibles',
      'Para qué usamos sus datos',
      'Cómo limitar el uso o la divulgación',
      'acceso, rectificación, cancelación y oposición',
      'Cambios a este aviso',
      'AVISO DE PRIVACIDAD SIMPLIFICADO',
    ]) {
      expect(aviso).toContain(elemento);
    }
  });

  it('test_los_terminos_y_el_aviso_son_textos_distintos', () => {
    expect(sql).toContain('TÉRMINOS Y CONDICIONES DE USO DE MOTORIX');
    expect(sql).toContain('AVISO DE PRIVACIDAD INTEGRAL');
  });
});

describe('fillShopData', () => {
  const shop = { name: 'Taller Uno', address: 'Av. Sur 1', phone: '555' };

  it('test_reemplaza_todos_los_marcadores_repetidos', () => {
    expect(fillShopData('{{TALLER_NOMBRE}} y {{TALLER_NOMBRE}}', shop)).toBe('Taller Uno y Taller Uno');
  });

  it('test_deja_pasar_nulos_y_no_toca_otros_textos_entre_llaves', () => {
    expect(fillShopData(null, shop)).toBeNull();
    expect(fillShopData('{{OTRO}}', shop)).toBe('{{OTRO}}');
  });
});
