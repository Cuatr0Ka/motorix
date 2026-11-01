import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createOrderPart,
  createPart,
  createPayableOrder,
  createPayment,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;
let cobrada;
let sinCobrar;
let parte;

const obtener = async (ruta, user) => {
  const res = await request(app).get(ruta).set(auth(user.token));
  expect(`${ruta} -> ${res.status}`).toBe(`${ruta} -> 200`);
  return res.body;
};

/** Todas las claves de un JSON (a cualquier profundidad). */
function claves(valor, acumulado = new Set()) {
  if (Array.isArray(valor)) valor.forEach((v) => claves(v, acumulado));
  else if (valor && typeof valor === 'object') {
    for (const [clave, hijo] of Object.entries(valor)) {
      acumulado.add(clave);
      claves(hijo, acumulado);
    }
  }
  return acumulado;
}

/** Foto de lo que consultan el panel y los listados. */
async function foto() {
  const panel = await obtener('/api/dashboard', admin);
  // La hora en que se generó el panel cambia en cada consulta: no forma parte de lo que se compara.
  delete panel.data.generatedAt;
  return {
    panel,
    ordenes: await obtener('/api/orders?pageSize=100', recepcion),
    ordenesMecanico: await obtener('/api/orders?pageSize=100', mecanico),
    pagos: await obtener('/api/payments?pageSize=100', recepcion),
    tickets: await obtener('/api/tickets?pageSize=100', recepcion),
  };
}

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle: v1 } = await createClientWithVehicle({ licensePlate: 'DSH-001-A' });
  const { vehicle: v2 } = await createClientWithVehicle({ licensePlate: 'DSH-002-A' });
  cobrada = await createPayableOrder(v1.id, recepcion.id, mecanico.id);
  sinCobrar = await createPayableOrder(v2.id, recepcion.id, mecanico.id);
  await createPayment(cobrada.id, recepcion.id);
  parte = await createPart(admin.id, { code: 'DSH-REF', stock: 20, salePrice: 180 });
});

describe('panel y listados con refacciones con precio (FR-016, CA-11)', () => {
  it('test_el_panel_y_los_listados_devuelven_lo_mismo_despues_de_agregar_refacciones_con_precio_a_una_orden', async () => {
    const antes = await foto();

    await createOrderPart(sinCobrar.id, parte.id, mecanico.id, 3, '180.00');
    const despues = await foto();

    expect(despues).toEqual(antes);
  });

  it('test_los_importes_del_panel_salen_de_los_pagos_registrados_y_no_del_total_de_las_ordenes', async () => {
    await createOrderPart(sinCobrar.id, parte.id, mecanico.id, 3, '180.00');

    const panel = await obtener('/api/dashboard', admin);
    const texto = JSON.stringify(panel);

    // Total de la orden sin cobrar con refacciones: 1250.00 + 540.00 = 1790.00. No debe aparecer en el panel.
    expect(texto).not.toContain('1790');
    expect(texto).not.toContain('540.00');
    expect(texto).toContain('1250.00');
  });

  it('test_ningun_listado_calcula_ni_muestra_el_total_de_la_orden', async () => {
    await createOrderPart(sinCobrar.id, parte.id, mecanico.id, 3, '180.00');
    const { ordenes, ordenesMecanico, pagos, tickets } = await foto();

    for (const listado of [ordenes, ordenesMecanico]) {
      const usadas = claves(listado.data);
      for (const prohibida of ['totals', 'parts', 'billing', 'unitPrice', 'breakdown']) expect([prohibida, usadas.has(prohibida)]).toEqual([prohibida, false]);
    }
    expect(JSON.stringify(pagos.data)).not.toMatch(/1790|540\.00/);
    expect(JSON.stringify(tickets.data)).not.toMatch(/1790|540\.00/);
  });

  it('test_el_listado_de_pagos_conserva_el_importe_de_cada_pago_aunque_cambie_el_total_de_la_orden', async () => {
    await createOrderPart(cobrada.id, parte.id, mecanico.id, 2, '180.00');

    const pagos = await obtener('/api/payments?pageSize=100', recepcion);

    expect(pagos.data).toHaveLength(1);
    expect(pagos.data[0]).toMatchObject({ orderId: cobrada.id, amount: '1250.00', status: 'PAGADO' });
  });

  it('test_el_total_con_refacciones_solo_aparece_en_el_detalle_de_la_orden', async () => {
    await createOrderPart(sinCobrar.id, parte.id, mecanico.id, 3, '180.00');

    const detalle = await obtener(`/api/orders/${sinCobrar.id}`, recepcion);

    expect(detalle.data.totals).toEqual({ services: '850.00', labor: '400.00', parts: '540.00', total: '1790.00' });
    expect(detalle.data.billing.total).toBe('1790.00');
  });

  it('test_los_indicadores_de_ordenes_terminadas_por_cobrar_siguen_contando_ordenes_y_no_importes', async () => {
    const antes = (await obtener('/api/dashboard', admin)).data;

    await createOrderPart(sinCobrar.id, parte.id, mecanico.id, 3, '180.00');
    const despues = (await obtener('/api/dashboard', admin)).data;

    expect(despues.payments).toEqual(antes.payments);
    expect(despues.orders).toEqual(antes.orders);
  });
});
