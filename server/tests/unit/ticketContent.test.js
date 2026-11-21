import { describe, expect, it } from '@jest/globals';
import { buildTicketContent, formatTicketFolio } from '../../services/ticketContent.js';

// Servicios 970.50 + mano de obra 400.00 + refacciones 1200.00 = 2570.50 (el importe del pago registrado).
const base = () => ({
  shop: { name: 'Taller de Prueba', address: 'Calle 1 #23', phone: '5555555555' },
  order: { id: 12, entryMileage: 84500, serviceMileage: 84620 },
  customer: { name: 'Ana Morales', phone: '5512345678' },
  vehicle: { licensePlate: 'ABC-123-A', brand: 'Nissan', model: 'Versa', year: 2019 },
  services: [
    { description: 'Cambio de balatas', amount: '850.00' },
    { description: 'Rotación de llantas', amount: '120.50' },
  ],
  parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 1, unitPrice: '1200.00', amount: '1200.00' }],
  labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
  payment: { amount: '2570.50', method: 'EFECTIVO', status: 'PAGADO', paidAt: new Date('2026-10-11T15:00:00.000Z'), reference: 'TERM-1' },
  now: new Date('2026-10-11T15:10:00.000Z'),
});

describe('folio del ticket', () => {
  it.each([[1, 'TK-000001'], [12, 'TK-000012'], [123456, 'TK-123456'], [1234567, 'TK-1234567']])('test_el_folio_de_%i_es_%s', (id, folio) => {
    expect(formatTicketFolio(id)).toBe(folio);
  });
});

describe('contenido del ticket versión 2 (FR-007, CA-4, CA-7)', () => {
  it('test_incluye_todos_los_campos_requeridos_con_el_formato_version_2', () => {
    const contenido = buildTicketContent(base());

    expect(contenido).toEqual({
      formatVersion: 2,
      shop: { name: 'Taller de Prueba', address: 'Calle 1 #23', phone: '5555555555' },
      customer: { name: 'Ana Morales', phone: '5512345678' },
      vehicle: { plate: 'ABC-123-A', brand: 'Nissan', model: 'Versa', year: 2019, mileage: 84620 },
      order: { folio: 'OS-000012', entryMileage: 84500, serviceMileage: 84620 },
      services: [
        { description: 'Cambio de balatas', amount: '850.00' },
        { description: 'Rotación de llantas', amount: '120.50' },
      ],
      parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 1, unitPrice: '1200.00', amount: '1200.00' }],
      labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
      totals: { services: '970.50', labor: '400.00', parts: '1200.00', total: '2570.50' },
      payment: { method: 'EFECTIVO', status: 'PAGADO', paidAt: '2026-10-11T15:00:00.000Z', reference: 'TERM-1' },
      generatedAt: '2026-10-11T15:10:00.000Z',
    });
  });

  it('test_usa_el_kilometraje_de_entrada_si_no_hay_kilometraje_de_servicio', () => {
    const datos = base();
    datos.order.serviceMileage = null;

    const contenido = buildTicketContent(datos);

    expect(contenido.vehicle.mileage).toBe(84500);
    expect(contenido.order.serviceMileage).toBeNull();
  });

  it('test_cada_refaccion_lleva_cantidad_precio_unitario_e_importe_y_el_subtotal_las_suma', () => {
    const datos = base();
    datos.parts = [
      { code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 4, unitPrice: '180.00', amount: '720.00' },
      { code: 'B', name: 'Pieza B', unit: 'litro', quantity: 3, unitPrice: '0.10', amount: '0.30' },
    ];
    datos.payment.amount = '2060.80';

    const contenido = buildTicketContent(datos);

    expect(contenido.parts).toEqual([
      { code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 4, unitPrice: '180.00', amount: '720.00' },
      { code: 'B', name: 'Pieza B', unit: 'litro', quantity: 3, unitPrice: '0.10', amount: '0.30' },
    ]);
    expect(contenido.totals.parts).toBe('720.30');
  });

  it('test_no_arrastra_campos_ajenos_a_las_refacciones', () => {
    const datos = base();
    datos.parts = [{ code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 1, unitPrice: '10.00', amount: '10.00', purchasePrice: '4.00', partId: 7 }];
    datos.payment.amount = '1390.50';

    const texto = JSON.stringify(buildTicketContent(datos));

    expect(texto).not.toContain('purchasePrice');
    expect(texto).not.toContain('partId');
  });

  it('test_las_lineas_anteriores_a_los_precios_aparecen_con_cero_y_no_suman', () => {
    const datos = base();
    datos.parts = [{ code: 'OLD', name: 'Pieza anterior', unit: 'pieza', quantity: 2, unitPrice: '0.00', amount: '0.00' }];
    datos.payment.amount = '1370.50';

    const contenido = buildTicketContent(datos);

    expect(contenido.parts[0]).toMatchObject({ unitPrice: '0.00', amount: '0.00' });
    expect(contenido.totals).toEqual({ services: '970.50', labor: '400.00', parts: '0.00', total: '1370.50' });
  });

  it('test_el_total_es_el_importe_del_pago_registrado_y_no_se_recalcula', () => {
    const datos = base();
    // Si los conceptos cambian después del pago, el total del ticket sigue siendo lo que se cobró.
    datos.payment.amount = '2000.00';

    const contenido = buildTicketContent(datos);

    expect(contenido.totals.total).toBe('2000.00');
    expect(contenido.totals.services).toBe('970.50');
    expect(contenido.totals.parts).toBe('1200.00');
  });

  it('test_suma_en_centavos_exactos_sin_errores_de_redondeo', () => {
    const datos = base();
    datos.services = [
      { description: 'A', amount: '0.10' },
      { description: 'B', amount: '0.20' },
      { description: 'C', amount: '19.99' },
    ];
    datos.labor = [{ description: 'D', amount: '0.01' }];
    datos.parts = [];
    datos.payment.amount = '20.30';

    const contenido = buildTicketContent(datos);

    expect(contenido.totals).toEqual({ services: '20.29', labor: '0.01', parts: '0.00', total: '20.30' });
  });

  it('test_una_orden_sin_refacciones_ni_mano_de_obra_tiene_listas_vacias_y_subtotales_en_cero', () => {
    const datos = base();
    datos.parts = [];
    datos.labor = [];
    datos.payment.amount = '970.50';

    const contenido = buildTicketContent(datos);

    expect(contenido.parts).toEqual([]);
    expect(contenido.labor).toEqual([]);
    expect(contenido.totals).toEqual({ services: '970.50', labor: '0.00', parts: '0.00', total: '970.50' });
  });

  it('test_una_orden_con_solo_refacciones_tiene_total_igual_al_subtotal_de_refacciones', () => {
    const datos = base();
    datos.services = [];
    datos.labor = [];
    datos.parts = [{ code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 1, unitPrice: '180.00', amount: '180.00' }];
    datos.payment.amount = '180.00';

    const contenido = buildTicketContent(datos);

    expect(contenido.totals).toEqual({ services: '0.00', labor: '0.00', parts: '180.00', total: '180.00' });
  });

  it('test_el_cliente_sin_telefono_y_el_pago_sin_referencia_quedan_en_null', () => {
    const datos = base();
    datos.customer.phone = undefined;
    datos.payment.reference = undefined;
    datos.payment.paidAt = null;

    const contenido = buildTicketContent(datos);

    expect(contenido.customer.phone).toBeNull();
    expect(contenido.payment.reference).toBeNull();
    expect(contenido.payment.paidAt).toBeNull();
  });

  it('test_no_incluye_datos_de_tarjeta_aunque_vengan_en_los_datos_de_entrada', () => {
    const datos = base();
    datos.payment.cardNumber = '4111111111111111';
    datos.payment.cvv = '123';
    datos.customer.cardNumber = '4111111111111111';

    const texto = JSON.stringify(buildTicketContent(datos));

    expect(texto).not.toContain('4111');
    expect(texto).not.toMatch(/cvv|cardNumber|card_number/i);
  });

  it('test_el_resultado_es_independiente_de_los_datos_de_entrada_posteriores', () => {
    const datos = base();
    const contenido = buildTicketContent(datos);

    datos.services[0].amount = '1.00';
    datos.parts[0].unitPrice = '1.00';
    datos.customer.name = 'Otra persona';
    datos.vehicle.licensePlate = 'ZZZ-999-Z';

    expect(contenido.services[0].amount).toBe('850.00');
    expect(contenido.parts[0].unitPrice).toBe('1200.00');
    expect(contenido.customer.name).toBe('Ana Morales');
    expect(contenido.vehicle.plate).toBe('ABC-123-A');
  });
});

describe('próximo servicio en el ticket versión 3 (US8, FR-009)', () => {
  it('test_con_next_service_el_contenido_es_version_3_y_lleva_el_bloque', () => {
    const contenido = buildTicketContent({
      ...base(),
      nextService: { dueDate: '2027-05-20', dueMileage: 90000, description: 'Cambio de aceite' },
    });

    expect(contenido.formatVersion).toBe(3);
    expect(contenido.nextService).toEqual({ dueDate: '2027-05-20', dueMileage: 90000, description: 'Cambio de aceite' });
  });

  it('test_sin_next_service_conserva_la_version_2_y_no_trae_el_campo', () => {
    const contenido = buildTicketContent(base());

    expect(contenido.formatVersion).toBe(2);
    expect(contenido).not.toHaveProperty('nextService');
  });

  it('test_acepta_solo_fecha_o_solo_kilometraje', () => {
    const soloFecha = buildTicketContent({ ...base(), nextService: { dueDate: '2027-01-10', dueMileage: null, description: 'Revisión' } });
    const soloKm = buildTicketContent({ ...base(), nextService: { dueDate: null, dueMileage: 95000, description: 'Revisión' } });

    expect(soloFecha.nextService).toEqual({ dueDate: '2027-01-10', dueMileage: null, description: 'Revisión' });
    expect(soloKm.nextService).toEqual({ dueDate: null, dueMileage: 95000, description: 'Revisión' });
  });
});
