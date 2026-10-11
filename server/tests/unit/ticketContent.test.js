import { describe, expect, it } from '@jest/globals';
import { buildTicketContent, formatTicketFolio } from '../../services/ticketContent.js';

const base = () => ({
  shop: { name: 'Taller de Prueba', address: 'Calle 1 #23', phone: '5555555555' },
  order: { id: 12, entryMileage: 84500, serviceMileage: 84620 },
  customer: { name: 'Ana Morales', phone: '5512345678' },
  vehicle: { licensePlate: 'ABC-123-A', brand: 'Nissan', model: 'Versa', year: 2019 },
  services: [
    { description: 'Cambio de balatas', amount: '850.00' },
    { description: 'Rotación de llantas', amount: '120.50' },
  ],
  parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 1 }],
  labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
  payment: { method: 'EFECTIVO', status: 'PAGADO', paidAt: new Date('2026-10-11T15:00:00.000Z'), reference: 'TERM-1' },
  now: new Date('2026-10-11T15:10:00.000Z'),
});

describe('folio del ticket', () => {
  it.each([[1, 'TK-000001'], [12, 'TK-000012'], [123456, 'TK-123456'], [1234567, 'TK-1234567']])('test_el_folio_de_%i_es_%s', (id, folio) => {
    expect(formatTicketFolio(id)).toBe(folio);
  });
});

describe('contenido del ticket (CA-4, FR-013)', () => {
  it('test_incluye_todos_los_campos_requeridos', () => {
    const contenido = buildTicketContent(base());

    expect(contenido).toEqual({
      shop: { name: 'Taller de Prueba', address: 'Calle 1 #23', phone: '5555555555' },
      customer: { name: 'Ana Morales', phone: '5512345678' },
      vehicle: { plate: 'ABC-123-A', brand: 'Nissan', model: 'Versa', year: 2019, mileage: 84620 },
      order: { folio: 'OS-000012', entryMileage: 84500, serviceMileage: 84620 },
      services: [
        { description: 'Cambio de balatas', amount: '850.00' },
        { description: 'Rotación de llantas', amount: '120.50' },
      ],
      parts: [{ code: 'BAL-DEL', name: 'Balatas delanteras', unit: 'juego', quantity: 1 }],
      labor: [{ description: 'Mano de obra frenos', amount: '400.00' }],
      totals: { services: '970.50', labor: '400.00', total: '1370.50' },
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

  it('test_las_refacciones_se_listan_con_cantidad_y_no_suman_importe', () => {
    const datos = base();
    datos.parts = [
      { code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 4, amount: '9999.00', price: '5000' },
      { code: 'B', name: 'Pieza B', unit: 'litro', quantity: 2 },
    ];

    const contenido = buildTicketContent(datos);

    expect(contenido.parts).toEqual([
      { code: 'A', name: 'Pieza A', unit: 'pieza', quantity: 4 },
      { code: 'B', name: 'Pieza B', unit: 'litro', quantity: 2 },
    ]);
    expect(contenido.totals.total).toBe('1370.50');
  });

  it('test_suma_en_centavos_exactos_sin_errores_de_redondeo', () => {
    const datos = base();
    datos.services = [
      { description: 'A', amount: '0.10' },
      { description: 'B', amount: '0.20' },
      { description: 'C', amount: '19.99' },
    ];
    datos.labor = [{ description: 'D', amount: '0.01' }];

    const contenido = buildTicketContent(datos);

    expect(contenido.totals).toEqual({ services: '20.29', labor: '0.01', total: '20.30' });
  });

  it('test_una_orden_sin_refacciones_ni_mano_de_obra_tiene_listas_vacias_y_subtotales_en_cero', () => {
    const datos = base();
    datos.parts = [];
    datos.labor = [];

    const contenido = buildTicketContent(datos);

    expect(contenido.parts).toEqual([]);
    expect(contenido.labor).toEqual([]);
    expect(contenido.totals).toEqual({ services: '970.50', labor: '0.00', total: '970.50' });
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
    datos.customer.name = 'Otra persona';
    datos.vehicle.licensePlate = 'ZZZ-999-Z';

    expect(contenido.services[0].amount).toBe('850.00');
    expect(contenido.customer.name).toBe('Ana Morales');
    expect(contenido.vehicle.plate).toBe('ABC-123-A');
  });
});
