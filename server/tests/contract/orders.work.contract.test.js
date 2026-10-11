import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import {
  auth,
  createClientWithVehicle,
  createLabor,
  createOrder,
  createService,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
let recepcion;
let mecanico;
let orden;

const tipos = [
  ['services', 'servicios'],
  ['labor', 'mano de obra'],
];

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'WRK-001-A' });
  orden = await createOrder(vehicle.id, recepcion.id, { mechanicId: mecanico.id, status: 'DIAGNOSTICO' });
});

describe('PATCH /api/orders/:id/work (contrato)', () => {
  it('test_guarda_diagnostico_observaciones_y_recomendaciones_y_devuelve_el_detalle', async () => {
    const res = await request(app)
      .patch(`/api/orders/${orden.id}/work`)
      .set(auth(mecanico.token))
      .send({ diagnosis: 'Balatas gastadas', observations: 'Disco rayado', recommendations: 'Cambiar discos' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: orden.id,
      diagnosis: 'Balatas gastadas',
      observations: 'Disco rayado',
      recommendations: 'Cambiar discos',
      services: [],
      labor: [],
      totals: { services: '0.00', labor: '0.00', total: '0.00' },
    });
  });

  it('test_rechaza_un_cuerpo_vacio_o_un_texto_demasiado_largo_con_400', async () => {
    const vacio = await request(app).patch(`/api/orders/${orden.id}/work`).set(auth(mecanico.token)).send({});
    const largo = await request(app)
      .patch(`/api/orders/${orden.id}/work`)
      .set(auth(mecanico.token))
      .send({ diagnosis: 'x'.repeat(5001) });

    expect(vacio.status).toBe(400);
    expect(largo.status).toBe(400);
    expect(largo.body.error.details[0].field).toBe('diagnosis');
  });

  it('test_sin_token_401_y_recepcion_403', async () => {
    expect((await request(app).patch(`/api/orders/${orden.id}/work`).send({ diagnosis: 'x' })).status).toBe(401);
    const res = await request(app).patch(`/api/orders/${orden.id}/work`).set(auth(recepcion.token)).send({ diagnosis: 'x' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});

describe.each(tipos)('líneas de %s (contrato)', (kind) => {
  const base = `/api/orders`;

  it('test_crea_una_linea_con_201_y_devuelve_la_linea_y_los_totales', async () => {
    const res = await request(app)
      .post(`${base}/${orden.id}/${kind}`)
      .set(auth(mecanico.token))
      .send({ description: 'Cambio de balatas', amount: 850 });

    expect(res.status).toBe(201);
    expect(res.body.data.item).toEqual({ id: expect.any(Number), description: 'Cambio de balatas', amount: '850.00' });
    expect(res.body.data.totals).toEqual({
      services: kind === 'services' ? '850.00' : '0.00',
      labor: kind === 'labor' ? '850.00' : '0.00',
      total: '850.00',
    });
  });

  it('test_corrige_una_linea_con_200', async () => {
    const linea = kind === 'services' ? await createService(orden.id) : await createLabor(orden.id);

    const res = await request(app)
      .patch(`${base}/${orden.id}/${kind}/${linea.id}`)
      .set(auth(mecanico.token))
      .send({ amount: '1200.50' });

    expect(res.status).toBe(200);
    expect(res.body.data.item).toMatchObject({ id: linea.id, amount: '1200.50' });
    expect(res.body.data.totals.total).toBe('1200.50');
  });

  it('test_quita_una_linea_con_200_y_totales_recalculados', async () => {
    const linea = kind === 'services' ? await createService(orden.id) : await createLabor(orden.id);

    const res = await request(app).delete(`${base}/${orden.id}/${kind}/${linea.id}`).set(auth(mecanico.token));

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ deleted: true, totals: { services: '0.00', labor: '0.00', total: '0.00' } });
  });

  it('test_rechaza_importe_negativo_o_descripcion_vacia_con_400_y_detalle_por_campo', async () => {
    const res = await request(app)
      .post(`${base}/${orden.id}/${kind}`)
      .set(auth(mecanico.token))
      .send({ description: '   ', amount: -5 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field).sort()).toEqual(['amount', 'description']);
  });

  it('test_sin_token_401_y_recepcion_403_en_cada_operacion', async () => {
    const linea = kind === 'services' ? await createService(orden.id) : await createLabor(orden.id);
    const operaciones = [
      (r) => r.post(`${base}/${orden.id}/${kind}`).send({ description: 'x', amount: 1 }),
      (r) => r.patch(`${base}/${orden.id}/${kind}/${linea.id}`).send({ amount: 2 }),
      (r) => r.delete(`${base}/${orden.id}/${kind}/${linea.id}`),
    ];

    for (const operacion of operaciones) {
      expect((await operacion(request(app))).status).toBe(401);
      const res = await operacion(request(app)).set(auth(recepcion.token));
      expect(res.status).toBe(403);
    }
  });
});
