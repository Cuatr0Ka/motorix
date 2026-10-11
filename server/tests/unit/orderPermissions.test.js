import { describe, expect, it } from '@jest/globals';
import { allowedFor, canActorTransition } from '../../services/orderTransitions.js';

const orden = (status, mechanicId = 10) => ({ status, mechanicId });
const asignado = { role: 'MECHANIC', userId: 10 };
const ajeno = { role: 'MECHANIC', userId: 11 };
const admin = { role: 'ADMIN', userId: 1 };
const recepcion = { role: 'RECEPTIONIST', userId: 2 };

describe('permisos para cambiar el estado (FR-020, FR-022)', () => {
  it('test_el_mecanico_asignado_avanza_hasta_terminado', () => {
    for (const to of ['DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO']) {
      expect(canActorTransition({ ...asignado, order: orden('RECIBIDO'), to })).toBe(true);
    }
  });

  it('test_el_mecanico_no_puede_entregar', () => {
    expect(canActorTransition({ ...asignado, order: orden('TERMINADO'), to: 'ENTREGADO' })).toBe(false);
  });

  it('test_un_mecanico_ajeno_no_puede_cambiar_el_estado', () => {
    expect(canActorTransition({ ...ajeno, order: orden('RECIBIDO'), to: 'DIAGNOSTICO' })).toBe(false);
  });

  it('test_una_orden_sin_mecanico_no_es_de_ningun_mecanico', () => {
    expect(canActorTransition({ ...asignado, order: orden('RECIBIDO', null), to: 'DIAGNOSTICO' })).toBe(false);
  });

  it('test_recepcion_no_avanza_hasta_terminado_pero_si_entrega', () => {
    expect(canActorTransition({ ...recepcion, order: orden('RECIBIDO'), to: 'DIAGNOSTICO' })).toBe(false);
    expect(canActorTransition({ ...recepcion, order: orden('EN_REPARACION'), to: 'TERMINADO' })).toBe(false);
    expect(canActorTransition({ ...recepcion, order: orden('TERMINADO'), to: 'ENTREGADO' })).toBe(true);
  });

  it('test_el_administrador_puede_todo', () => {
    expect(canActorTransition({ ...admin, order: orden('RECIBIDO', null), to: 'DIAGNOSTICO' })).toBe(true);
    expect(canActorTransition({ ...admin, order: orden('TERMINADO'), to: 'ENTREGADO' })).toBe(true);
  });

  it('test_allowed_for_filtra_por_rol_y_pertenencia', () => {
    expect(allowedFor({ ...asignado, order: orden('DIAGNOSTICO') })).toEqual(['EN_REPARACION', 'ESPERANDO_REFACCION']);
    expect(allowedFor({ ...ajeno, order: orden('DIAGNOSTICO') })).toEqual([]);
    expect(allowedFor({ ...recepcion, order: orden('DIAGNOSTICO') })).toEqual([]);
    expect(allowedFor({ ...recepcion, order: orden('TERMINADO') })).toEqual(['ENTREGADO']);
    expect(allowedFor({ ...asignado, order: orden('TERMINADO') })).toEqual([]);
    expect(allowedFor({ ...admin, order: orden('ENTREGADO') })).toEqual([]);
  });
});
