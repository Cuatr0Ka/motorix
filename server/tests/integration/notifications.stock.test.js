import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { auth, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const consultar = (user) => request(app).get('/api/notifications').set(auth(user.token));
const grupo = (res, tipo) => res.body.data.groups.find((g) => g.type === tipo);

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('avisos de stock bajo o agotado (US3, FR-004, FR-005)', () => {
  it('test_el_administrador_recibe_stock_bajo_y_agotado_en_grupos_separados', async () => {
    const bajo = await createPart(admin.id, { stock: 3, minStock: 3, name: 'Filtro de aceite' });
    const agotado = await createPart(admin.id, { stock: 0, minStock: 4, name: 'Balatas' });
    await createPart(admin.id, { stock: 50, minStock: 3, name: 'Bujías' });

    const res = await consultar(admin);

    expect(res.status).toBe(200);
    expect(res.body.data.groups.map((g) => g.type)).toEqual(['STOCK_OUT', 'STOCK_LOW']);
    const out = grupo(res, 'STOCK_OUT').items[0];
    expect(out.key).toBe(`STOCK_OUT:${agotado.id}`);
    expect(out.title).toBe('Stock agotado');
    expect(out.detail).toContain('Balatas');
    expect(out.stock).toBe(0);
    expect(out.minStock).toBe(4);
    expect(out.target).toEqual({ kind: 'part', id: agotado.id });
    const low = grupo(res, 'STOCK_LOW').items[0];
    expect(low.key).toBe(`STOCK_LOW:${bajo.id}`);
    expect(low.title).toBe('Stock bajo');
    expect(low.detail).toContain('Filtro de aceite');
    expect(low.stock).toBe(3);
    expect(low.minStock).toBe(3);
  });

  it('test_una_refaccion_inactiva_no_genera_aviso', async () => {
    await createPart(admin.id, { stock: 0, minStock: 4, active: 0 });

    const res = await consultar(admin);

    expect(res.body.data.groups).toEqual([]);
  });

  it('test_una_refaccion_con_stock_suficiente_no_genera_aviso', async () => {
    await createPart(admin.id, { stock: 4, minStock: 3 });

    const res = await consultar(admin);

    expect(res.body.data.total).toBe(0);
  });

  it('test_el_total_coincide_con_las_alertas_del_inventario_y_con_el_panel', async () => {
    await createPart(admin.id, { stock: 1, minStock: 3 });
    await createPart(admin.id, { stock: 2, minStock: 3 });
    await createPart(admin.id, { stock: 0, minStock: 5 });

    const avisos = await consultar(admin);
    const alertas = await request(app).get('/api/parts/alerts').set(auth(admin.token));
    const panel = await request(app).get('/api/dashboard').set(auth(admin.token));

    const stock = grupo(avisos, 'STOCK_LOW').total + grupo(avisos, 'STOCK_OUT').total;
    expect(stock).toBe(alertas.body.data.count);
    expect(grupo(avisos, 'STOCK_OUT').total).toBe(alertas.body.data.outOfStock);
    expect(grupo(avisos, 'STOCK_OUT').total).toBe(panel.body.data.inventory.outOfStock);
    expect(stock).toBe(panel.body.data.inventory.lowStock);
  });

  it('test_al_agotarse_una_refaccion_el_aviso_leido_de_stock_bajo_reaparece_como_agotado', async () => {
    const parte = await createPart(admin.id, { stock: 2, minStock: 3 });
    await request(app).post('/api/notifications/read').set(auth(admin.token)).send({ keys: [`STOCK_LOW:${parte.id}`] });
    expect((await consultar(admin)).body.data.unread).toBe(0);

    const { query } = await import('../../config/db.js');
    await query('UPDATE parts SET stock = 0 WHERE id = ?', [parte.id]);
    const res = await consultar(admin);

    expect(res.body.data.groups.map((g) => g.type)).toEqual(['STOCK_OUT']);
    expect(grupo(res, 'STOCK_OUT').items[0].read).toBe(false);
    expect(res.body.data.unread).toBe(1);
  });

  it('test_la_recepcion_y_el_mecanico_no_reciben_ningun_aviso_de_stock', async () => {
    await createPart(admin.id, { stock: 0, minStock: 5 });
    await createPart(admin.id, { stock: 1, minStock: 5 });

    for (const usuario of [recepcion, mecanico]) {
      const res = await consultar(usuario);
      expect(res.status).toBe(200);
      expect(res.body.data.groups).toEqual([]);
      expect(JSON.stringify(res.body)).not.toMatch(/STOCK_/);
    }
  });

  it('test_no_se_pueden_marcar_como_leidos_los_avisos_de_stock_sin_ser_administrador', async () => {
    const parte = await createPart(admin.id, { stock: 0, minStock: 5 });

    for (const usuario of [recepcion, mecanico]) {
      const res = await request(app)
        .post('/api/notifications/read')
        .set(auth(usuario.token))
        .send({ keys: [`STOCK_OUT:${parte.id}`] });
      expect(res.status).toBe(200);
      expect(res.body.data.marked).toBe(0);
    }
  });
});
