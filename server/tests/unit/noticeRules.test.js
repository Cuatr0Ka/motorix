import { describe, expect, it } from '@jest/globals';
import {
  buildNoticeKey,
  daysSince,
  GROUP_ORDER,
  isStalledOrder,
  isValidNoticeKey,
  NOTICE_TYPES,
  STALLED_DAYS,
  typesForRole,
} from '../../services/noticeRules.js';

const HOY = new Date(2026, 10, 20, 15, 30); // 20 de noviembre de 2026, a media tarde

const detenida = (status, lastChangeAt) => isStalledOrder({ status, lastChangeAt, today: HOY });

describe('orden detenida (D-01, FR-013)', () => {
  it('test_el_valor_de_los_dias_es_tres', () => {
    expect(STALLED_DAYS).toBe(3);
  });

  it('test_tres_dias_exactos_no_es_detenida_y_cuatro_si', () => {
    expect(detenida('EN_REPARACION', new Date(2026, 10, 17, 8, 0))).toBe(false);
    expect(detenida('EN_REPARACION', new Date(2026, 10, 16, 23, 59))).toBe(true);
  });

  it('test_cuenta_dias_calendario_sin_importar_la_hora', () => {
    expect(daysSince(new Date(2026, 10, 19, 23, 59), HOY)).toBe(1);
    expect(daysSince(new Date(2026, 10, 20, 0, 1), HOY)).toBe(0);
  });

  it('test_aplica_a_los_cuatro_estados_abiertos', () => {
    const viejo = new Date(2026, 10, 1);
    for (const estado of ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION']) {
      expect(detenida(estado, viejo)).toBe(true);
    }
  });

  it('test_una_orden_terminada_o_entregada_nunca_es_detenida', () => {
    const viejo = new Date(2026, 10, 1);
    expect(detenida('TERMINADO', viejo)).toBe(false);
    expect(detenida('ENTREGADO', viejo)).toBe(false);
  });

  it('test_sin_fecha_de_cambio_no_es_detenida', () => {
    expect(detenida('RECIBIDO', null)).toBe(false);
    expect(detenida('RECIBIDO', undefined)).toBe(false);
  });

  it('test_una_fecha_futura_no_da_dias_negativos', () => {
    expect(daysSince(new Date(2026, 10, 25), HOY)).toBe(0);
  });
});

describe('claves de aviso (R-03)', () => {
  it('test_construye_las_claves_con_y_sin_variante', () => {
    expect(buildNoticeKey('STOCK_LOW', 12)).toBe('STOCK_LOW:12');
    expect(buildNoticeKey('STALLED', 5, 31)).toBe('STALLED:5:31');
    expect(buildNoticeKey('STALLED', 5, 0)).toBe('STALLED:5:0');
  });

  it('test_acepta_las_claves_bien_formadas', () => {
    for (const clave of ['MAINT_OVERDUE:7', 'MAINT_UPCOMING:7', 'APPT_TODAY:3', 'STOCK_OUT:1', 'STALLED:5:31', 'STALLED:5:0']) {
      expect(isValidNoticeKey(clave)).toBe(true);
    }
  });

  it('test_rechaza_las_claves_mal_formadas', () => {
    const malas = [
      '',
      'STOCK_LOW',
      'STOCK_LOW:',
      'STOCK_LOW:abc',
      'STOCK_LOW:0',
      'STOCK_LOW:-1',
      'OTRO:5',
      'STALLED:5:x',
      'STALLED:5:31:9',
      'stock_low:5',
      "STOCK_LOW:1' OR '1'='1",
      `STOCK_LOW:${'9'.repeat(70)}`,
    ];
    for (const clave of malas) expect(isValidNoticeKey(clave)).toBe(false);
    expect(isValidNoticeKey(null)).toBe(false);
    expect(isValidNoticeKey(12)).toBe(false);
  });
});

describe('visibilidad por rol (FR-004)', () => {
  it('test_el_administrador_recibe_todos_los_tipos', () => {
    expect(typesForRole('ADMIN').sort()).toEqual(Object.values(NOTICE_TYPES).sort());
  });

  it('test_la_recepcion_no_recibe_stock', () => {
    const tipos = typesForRole('RECEPTIONIST');
    expect(tipos).not.toContain('STOCK_LOW');
    expect(tipos).not.toContain('STOCK_OUT');
    expect([...tipos].sort()).toEqual(['APPT_TODAY', 'MAINT_OVERDUE', 'MAINT_UPCOMING', 'STALLED']);
  });

  it('test_el_mecanico_solo_recibe_ordenes_detenidas', () => {
    expect(typesForRole('MECHANIC')).toEqual(['STALLED']);
  });

  it('test_un_rol_desconocido_no_recibe_nada', () => {
    expect(typesForRole('OTRO')).toEqual([]);
    expect(typesForRole(undefined)).toEqual([]);
  });

  it('test_el_orden_de_los_grupos_cubre_todos_los_tipos_sin_repetir', () => {
    expect([...GROUP_ORDER].sort()).toEqual(Object.values(NOTICE_TYPES).sort());
    expect(GROUP_ORDER[0]).toBe('MAINT_OVERDUE');
  });
});
