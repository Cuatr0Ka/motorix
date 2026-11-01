import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { resetGateway, setGateway } from '../../integrations/mercadoPago.js';
import {
  FakeGateway,
  auth,
  createClientWithVehicle,
  createLabor,
  createMaintenance,
  createOrder,
  createOrderPart,
  createPart,
  createPayableOrder,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();

// Valores distintivos para poder buscarlos en cualquier respuesta aunque cambie el nombre del campo.
const COMPRA = '73.41';
const VENTA = '188.88';
const IMPORTE_LINEA = '377.76'; // 2 × 188.88

let admin;
let recepcion;
let mecanico;
let ids;

/** Rutas de consulta que recorre cada rol, con los identificadores de los datos de prueba. */
const rutas = () => [
  '/api/auth/me',
  '/api/parts?pageSize=100',
  '/api/parts?search=Frenos',
  `/api/parts/${ids.parteId}`,
  '/api/parts/alerts',
  `/api/parts/${ids.parteId}/movements`,
  '/api/orders?pageSize=100',
  `/api/orders/${ids.ordenId}`,
  `/api/orders/${ids.ordenId}/payments`,
  `/api/orders/${ids.ordenId}/ticket`,
  '/api/payments?pageSize=100',
  `/api/payments/${ids.pagoId}`,
  '/api/payments/methods',
  '/api/tickets?pageSize=100',
  `/api/tickets/${ids.ticketId}`,
  '/api/dashboard',
  '/api/vehicles?pageSize=100',
  `/api/vehicles/${ids.vehiculoId}`,
  `/api/vehicles/${ids.vehiculoId}/history`,
  '/api/clients?pageSize=100',
  `/api/clients/${ids.clienteId}`,
  '/api/appointments?pageSize=100',
  '/api/maintenance?pageSize=100',
  '/api/mechanics',
];

/** Recorre el JSON y llama a `visita(clave, valor, ruta)` por cada propiedad. */
function recorre(valor, visita, ruta = '$') {
  if (Array.isArray(valor)) {
    valor.forEach((elemento, i) => recorre(elemento, visita, `${ruta}[${i}]`));
  } else if (valor && typeof valor === 'object') {
    for (const [clave, hijo] of Object.entries(valor)) {
      visita(clave, hijo, `${ruta}.${clave}`);
      recorre(hijo, visita, `${ruta}.${clave}`);
    }
  }
}

async function consultar(user) {
  const resultados = [];
  for (const ruta of rutas()) {
    const res = await request(app).get(ruta).set(auth(user.token));
    resultados.push({ ruta, status: res.status, texto: JSON.stringify(res.body), cuerpo: res.body });
  }
  return resultados;
}

beforeEach(async () => {
  await resetDatabase();
  setGateway(new FakeGateway({ configured: true }));
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');

  const { client, vehicle } = await createClientWithVehicle({ licensePlate: 'LEA-001-A' });
  const parte = await createPart(admin.id, {
    code: 'LEA-REF',
    name: 'Balatas de prueba',
    category: 'Frenos',
    brand: 'Marca X',
    stock: 1,
    minStock: 3,
    purchasePrice: COMPRA,
    salePrice: VENTA,
  });
  const orden = await createPayableOrder(vehicle.id, recepcion.id, mecanico.id);
  await createOrderPart(orden.id, parte.id, mecanico.id, 2, VENTA);
  await createMaintenance(vehicle.id, orden.id, admin.id);
  const pago = await request(app).post(`/api/orders/${orden.id}/payments`).set(auth(recepcion.token)).send({ method: 'EFECTIVO' });
  const ticket = await request(app).post(`/api/orders/${orden.id}/ticket`).set(auth(recepcion.token));
  // Otra orden en curso con la misma refacción, para que aparezca también en listados y alertas.
  const { vehicle: otro } = await createClientWithVehicle({ licensePlate: 'LEA-002-A' });
  const enCurso = await createOrder(otro.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });
  await createService(enCurso.id);
  await createLabor(enCurso.id);

  ids = {
    clienteId: client.id,
    vehiculoId: vehicle.id,
    parteId: parte.id,
    ordenId: orden.id,
    pagoId: pago.body.data.id,
    ticketId: ticket.body.data.ticket.id,
  };
});

afterAll(() => resetGateway());

describe('el precio de compra solo llega al administrador (FR-013, SC-006)', () => {
  it('test_el_control_positivo_el_administrador_si_recibe_el_precio_de_compra_en_las_rutas_de_refacciones', async () => {
    const respuestas = await consultar(admin);
    const enRefacciones = respuestas.filter((r) => ['/api/parts?pageSize=100', `/api/parts/${ids.parteId}`, '/api/parts/alerts'].includes(r.ruta));

    expect(enRefacciones).toHaveLength(3);
    for (const respuesta of enRefacciones) {
      expect(respuesta.status).toBe(200);
      expect(respuesta.texto).toContain(COMPRA);
    }
  });

  it.each([
    ['recepción', () => recepcion],
    ['mecánico', () => mecanico],
  ])('test_%s_no_recibe_el_precio_de_compra_en_ninguna_ruta_de_consulta', async (_nombre, quien) => {
    const respuestas = await consultar(quien());
    const violaciones = [];

    for (const { ruta, texto, cuerpo } of respuestas) {
      if (texto.includes(COMPRA)) violaciones.push(`El valor del precio de compra aparece en ${ruta}`);
      recorre(cuerpo, (clave, _valor, camino) => {
        if (/^(purchasePrice|purchase_price)$/.test(clave)) violaciones.push(`La clave «${clave}» aparece en ${ruta} (${camino})`);
      });
    }

    expect(violaciones).toEqual([]);
  });

  it('test_ningun_rol_recibe_el_precio_de_compra_en_el_ticket', async () => {
    for (const user of [admin, recepcion]) {
      const porOrden = await request(app).get(`/api/orders/${ids.ordenId}/ticket`).set(auth(user.token));
      const porId = await request(app).get(`/api/tickets/${ids.ticketId}`).set(auth(user.token));

      expect(porOrden.status).toBe(200);
      expect(porId.status).toBe(200);
      expect(JSON.stringify(porOrden.body)).not.toContain(COMPRA);
      expect(JSON.stringify(porId.body)).not.toContain(COMPRA);
    }
  });

  it('test_el_panel_de_control_y_las_alertas_de_stock_no_filtran_precios_a_quien_no_es_administrador', async () => {
    const panel = await request(app).get('/api/dashboard').set(auth(recepcion.token));
    const alertasRecepcion = await request(app).get('/api/parts/alerts').set(auth(recepcion.token));
    const alertasMecanico = await request(app).get('/api/parts/alerts').set(auth(mecanico.token));

    expect(panel.status).toBe(403);
    expect(alertasRecepcion.status).toBe(403);
    expect(alertasMecanico.status).toBe(403);
  });
});

describe('el recorrido no es vacío: las rutas responden con datos reales', () => {
  it('test_los_roles_reciben_200_con_la_orden_y_la_refaccion_de_prueba_en_las_rutas_que_les_corresponden', async () => {
    const porRol = {
      ADMIN: await consultar(admin),
      RECEPTIONIST: await consultar(recepcion),
      MECHANIC: await consultar(mecanico),
    };
    const estado = (rol, ruta) => porRol[rol].find((r) => r.ruta === ruta).status;
    const texto = (rol, ruta) => porRol[rol].find((r) => r.ruta === ruta).texto;

    expect(estado('ADMIN', `/api/parts/${ids.parteId}`)).toBe(200);
    expect(estado('MECHANIC', '/api/parts?pageSize=100')).toBe(200);
    expect(texto('MECHANIC', '/api/parts?pageSize=100')).toContain('LEA-REF');
    for (const rol of Object.keys(porRol)) {
      expect(estado(rol, `/api/orders/${ids.ordenId}`)).toBe(200);
      expect(texto(rol, `/api/orders/${ids.ordenId}`)).toContain('LEA-REF');
    }
    expect(estado('RECEPTIONIST', `/api/tickets/${ids.ticketId}`)).toBe(200);
    expect(estado('RECEPTIONIST', `/api/vehicles/${ids.vehiculoId}/history`)).toBe(200);
    expect(Object.values(porRol).flat().filter((r) => r.status === 200).length).toBeGreaterThanOrEqual(40);
  });
});

describe('el mecánico no recibe ningún precio de refacciones (FR-014, SC-006)', () => {
  const CLAVES_PROHIBIDAS = /^(purchasePrice|salePrice|unitPrice|priceMissing|legacy|breakdown|billing|amountDifference|amountOutdated)$/;

  it('test_ninguna_ruta_de_consulta_le_entrega_claves_ni_valores_de_precios_de_refacciones', async () => {
    const respuestas = await consultar(mecanico);
    const violaciones = [];

    for (const { ruta, texto, cuerpo } of respuestas) {
      if (texto.includes(VENTA)) violaciones.push(`El precio de venta aparece en ${ruta}`);
      if (texto.includes(IMPORTE_LINEA)) violaciones.push(`El importe de la línea aparece en ${ruta}`);
      recorre(cuerpo, (clave, valor, camino) => {
        if (CLAVES_PROHIBIDAS.test(clave)) violaciones.push(`La clave «${clave}» aparece en ${ruta} (${camino})`);
        if (clave === 'totals' && valor && typeof valor === 'object' && 'parts' in valor) {
          violaciones.push(`Los totales del mecánico llevan refacciones en ${ruta} (${camino})`);
        }
        if (clave === 'parts' && Array.isArray(valor)) {
          for (const linea of valor) {
            if (linea && typeof linea === 'object' && 'amount' in linea) violaciones.push(`Una línea de refacción lleva importe en ${ruta} (${camino})`);
          }
        }
      });
    }

    expect(violaciones).toEqual([]);
  });

  it('test_las_rutas_de_cobro_pagos_y_tickets_le_responden_403', async () => {
    const respuestas = await consultar(mecanico);
    const cobro = respuestas.filter((r) => /\/payments|\/ticket|\/tickets/.test(r.ruta));

    expect(cobro.length).toBeGreaterThanOrEqual(7);
    expect(cobro.map((r) => `${r.ruta} -> ${r.status}`)).toEqual(cobro.map((r) => `${r.ruta} -> 403`));
  });

  it('test_las_respuestas_de_agregar_corregir_y_quitar_una_refaccion_tampoco_llevan_precios', async () => {
    const otra = await createPart(admin.id, { code: 'LEA-OTRA', stock: 9, purchasePrice: COMPRA, salePrice: VENTA });
    const { vehicle } = await createClientWithVehicle({ licensePlate: 'LEA-003-A' });
    const orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'EN_REPARACION' });

    const alta = await request(app).post(`/api/orders/${orden.id}/parts`).set(auth(mecanico.token)).send({ partId: otra.id, quantity: 2 });
    const linea = alta.body.data.item.id;
    const cambio = await request(app).patch(`/api/orders/${orden.id}/parts/${linea}`).set(auth(mecanico.token)).send({ quantity: 3 });
    const baja = await request(app).delete(`/api/orders/${orden.id}/parts/${linea}`).set(auth(mecanico.token));

    for (const res of [alta, cambio, baja]) {
      expect(res.status).toBeLessThan(300);
      const texto = JSON.stringify(res.body);
      expect(texto).not.toContain(COMPRA);
      expect(texto).not.toContain(VENTA);
      recorre(res.body, (clave) => expect(clave).not.toMatch(CLAVES_PROHIBIDAS));
    }
  });

  it('test_el_control_positivo_recepcion_si_recibe_el_precio_de_venta_en_el_detalle_de_la_orden', async () => {
    const res = await request(app).get(`/api/orders/${ids.ordenId}`).set(auth(recepcion.token));

    expect(res.status).toBe(200);
    expect(JSON.stringify(res.body)).toContain(VENTA);
    expect(JSON.stringify(res.body)).toContain(IMPORTE_LINEA);
  });
});
