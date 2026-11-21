import { describe, expect, it } from '@jest/globals';
import { projectForRole } from '../../services/notificationService.js';

const aviso = {
  key: 'STALLED:5:31',
  type: 'STALLED',
  read: false,
  title: 'Orden detenida',
  detail: 'OS-000005 · Nissan Versa ABC-123 · En reparación · 5 días sin cambio',
  folio: 'OS-000005',
  status: 'EN_REPARACION',
  daysStalled: 5,
  target: { kind: 'order', id: 5 },
  // Datos que nunca deben llegar al mecánico, aunque un cargador los agregara por error.
  client: { id: 9, name: 'Ana Torres', phone: '7761234567' },
  clientName: 'Ana Torres',
  phone: '7761234567',
};

describe('proyección del aviso según el rol (defensa en profundidad, FR-015)', () => {
  it('test_el_mecanico_conserva_solo_los_campos_permitidos', () => {
    const proyectado = projectForRole(aviso, 'MECHANIC');

    expect(Object.keys(proyectado).sort()).toEqual(
      ['daysStalled', 'detail', 'folio', 'key', 'read', 'status', 'target', 'title', 'type'].sort(),
    );
    expect(JSON.stringify(proyectado)).not.toContain('Ana Torres');
    expect(JSON.stringify(proyectado)).not.toContain('7761234567');
  });

  it('test_administracion_y_recepcion_reciben_el_aviso_sin_cambios', () => {
    expect(projectForRole(aviso, 'ADMIN')).toBe(aviso);
    expect(projectForRole(aviso, 'RECEPTIONIST')).toBe(aviso);
  });

  it('test_no_modifica_el_aviso_original', () => {
    projectForRole(aviso, 'MECHANIC');

    expect(aviso.client.name).toBe('Ana Torres');
  });
});
