import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createPart, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let admin;
let recepcion;
let mecanico;

const crear = (cuerpo, user = admin) => request(app).post('/api/parts').set(auth(user.token)).send(cuerpo);
const editar = (id, cuerpo, user = admin) => request(app).patch(`/api/parts/${id}`).set(auth(user.token)).send(cuerpo);
const datos = (extra = {}) => ({ code: 'FIL-ACE', name: 'Filtro de aceite', unit: 'pieza', minStock: 3, initialStock: 10, ...extra });
const filaEnBase = async (id) => (await query('SELECT * FROM parts WHERE id = ?', [id]))[0];

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('alta con categoría, marca y precios (US1)', () => {
  it('test_registra_la_refaccion_con_categoria_marca_y_ambos_precios', async () => {
    const res = await crear(datos({ category: 'Filtros', brand: 'Mann', purchasePrice: '120.00', salePrice: 180 }));

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      category: 'Filtros',
      brand: 'Mann',
      purchasePrice: '120.00',
      salePrice: '180.00',
      priceMissing: false,
    });
    const fila = await filaEnBase(res.body.data.id);
    expect(fila).toMatchObject({ category: 'Filtros', brand: 'Mann', purchase_price: '120.00', sale_price: '180.00' });
  });

  it('test_una_refaccion_sin_precios_se_registra_y_queda_marcada_sin_precio_de_venta', async () => {
    const res = await crear(datos());

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ category: null, brand: null, purchasePrice: null, salePrice: null, priceMissing: true });
  });

  it('test_el_precio_de_compra_es_opcional_y_puede_registrarse_en_cero', async () => {
    const res = await crear(datos({ purchasePrice: 0, salePrice: '50' }));

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ purchasePrice: '0.00', salePrice: '50.00' });
  });
});

describe('validación de los precios (FR-002)', () => {
  it.each([
    ['precio de compra negativo', { purchasePrice: -1 }, 'purchasePrice'],
    ['precio de venta negativo', { salePrice: -10 }, 'salePrice'],
    ['precio no numérico', { salePrice: 'caro' }, 'salePrice'],
    ['más de dos decimales', { purchasePrice: '10.999' }, 'purchasePrice'],
    ['precio de venta igual a cero', { salePrice: 0 }, 'salePrice'],
    ['precio por encima de 9 999 999.99', { salePrice: '10000000.00' }, 'salePrice'],
    ['categoría de 61 caracteres', { category: 'C'.repeat(61) }, 'category'],
    ['marca de 61 caracteres', { brand: 'M'.repeat(61) }, 'brand'],
  ])('test_rechaza_%s_con_400_y_el_campo_en_los_detalles', async (_caso, extra, campo) => {
    const res = await crear(datos(extra));

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
    expect(await query("SELECT id FROM parts WHERE code = 'FIL-ACE'")).toEqual([]);
  });

  it('test_acepta_el_precio_maximo_de_9999999_99', async () => {
    const res = await crear(datos({ salePrice: '9999999.99' }));

    expect(res.status).toBe(201);
    expect(res.body.data.salePrice).toBe('9999999.99');
  });

  it('test_la_base_rechaza_un_precio_de_venta_en_cero_aunque_falle_la_validacion', async () => {
    const parte = await createPart(admin.id, { salePrice: 10 });

    await expect(query('UPDATE parts SET sale_price = 0 WHERE id = ?', [parte.id])).rejects.toThrow();
    await expect(query('UPDATE parts SET purchase_price = -1 WHERE id = ?', [parte.id])).rejects.toThrow();
  });
});

describe('edición de precios', () => {
  it('test_edita_categoria_marca_y_precios_sin_alterar_el_codigo_ni_la_existencia', async () => {
    const parte = await createPart(admin.id, { code: 'EDI-001', stock: 7, minStock: 2 });

    const res = await editar(parte.id, { category: 'Frenos', brand: 'Brembo', purchasePrice: 300, salePrice: '450.50' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      code: 'EDI-001',
      stock: 7,
      category: 'Frenos',
      brand: 'Brembo',
      purchasePrice: '300.00',
      salePrice: '450.50',
    });
  });

  it('test_el_precio_de_compra_se_puede_borrar_y_el_de_venta_no', async () => {
    const parte = await createPart(admin.id, { purchasePrice: 60, salePrice: 100 });

    const borrarCompra = await editar(parte.id, { purchasePrice: null });
    const borrarVenta = await editar(parte.id, { salePrice: null });

    expect(borrarCompra.status).toBe(200);
    expect(borrarCompra.body.data.purchasePrice).toBeNull();
    expect(borrarVenta.status).toBe(400);
    expect(borrarVenta.body.error.details.map((d) => d.field)).toContain('salePrice');
    expect((await filaEnBase(parte.id)).sale_price).toBe('100.00');
  });

  it('test_un_precio_invalido_en_la_edicion_no_cambia_nada', async () => {
    const parte = await createPart(admin.id, { purchasePrice: 60, salePrice: 100 });

    const res = await editar(parte.id, { salePrice: '1.234' });

    expect(res.status).toBe(400);
    expect((await filaEnBase(parte.id)).sale_price).toBe('100.00');
  });
});

describe('venta bajo el costo (FR-025)', () => {
  it('test_el_alta_con_venta_menor_a_la_compra_responde_422_sin_guardar_nada', async () => {
    const res = await crear(datos({ purchasePrice: 120, salePrice: 90 }));

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PRICE_BELOW_COST');
    expect(res.body.error.details).toEqual({ salePrice: '90.00', purchasePrice: '120.00' });
    expect(await query("SELECT id FROM parts WHERE code = 'FIL-ACE'")).toEqual([]);
  });

  it('test_el_alta_con_confirmacion_explicita_guarda_la_refaccion', async () => {
    const res = await crear(datos({ purchasePrice: 120, salePrice: 90, confirmBelowCost: true }));

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ purchasePrice: '120.00', salePrice: '90.00' });
  });

  it('test_la_edicion_compara_contra_el_precio_vigente_cuando_solo_cambia_un_precio', async () => {
    const parte = await createPart(admin.id, { purchasePrice: 100, salePrice: 150 });

    const bajarVenta = await editar(parte.id, { salePrice: 90 });
    const subirCompra = await editar(parte.id, { purchasePrice: 200 });

    expect(bajarVenta.status).toBe(422);
    expect(bajarVenta.body.error.code).toBe('PRICE_BELOW_COST');
    expect(subirCompra.status).toBe(422);
    expect(subirCompra.body.error.details).toEqual({ salePrice: '150.00', purchasePrice: '200.00' });
    expect(await filaEnBase(parte.id)).toMatchObject({ purchase_price: '100.00', sale_price: '150.00' });

    const confirmada = await editar(parte.id, { salePrice: 90, confirmBelowCost: true });
    expect(confirmada.status).toBe(200);
    expect(confirmada.body.data.salePrice).toBe('90.00');
  });

  it('test_editar_solo_el_nombre_de_una_refaccion_ya_bajo_el_costo_no_pide_confirmacion', async () => {
    const parte = await createPart(admin.id, { purchasePrice: 120, salePrice: 90 });

    const res = await editar(parte.id, { name: 'Nombre corregido' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ name: 'Nombre corregido', purchasePrice: '120.00', salePrice: '90.00' });
  });

  it('test_una_venta_igual_a_la_compra_no_es_venta_bajo_el_costo', async () => {
    const res = await crear(datos({ purchasePrice: 100, salePrice: 100 }));

    expect(res.status).toBe(201);
  });
});

describe('búsqueda y señalamiento de la falta de precio (FR-001, FR-020)', () => {
  it('test_busca_por_categoria_y_por_marca', async () => {
    await createPart(admin.id, { code: 'BUS-001', name: 'Pieza uno', category: 'Suspensión', brand: 'Monroe' });
    await createPart(admin.id, { code: 'BUS-002', name: 'Pieza dos', category: 'Frenos', brand: 'Brembo' });

    const porCategoria = await request(app).get('/api/parts?search=Suspens').set(auth(admin.token));
    const porMarca = await request(app).get('/api/parts?search=Brembo').set(auth(admin.token));

    expect(porCategoria.body.data.map((p) => p.code)).toEqual(['BUS-001']);
    expect(porMarca.body.data.map((p) => p.code)).toEqual(['BUS-002']);
  });

  it('test_el_listado_marca_priceMissing_solo_en_las_refacciones_sin_precio_de_venta', async () => {
    await createPart(admin.id, { code: 'CON-PRE', name: 'Con precio', salePrice: 80 });
    await createPart(admin.id, { code: 'SIN-PRE', name: 'Sin precio', salePrice: null });

    const res = await request(app).get('/api/parts').set(auth(admin.token));
    const porCodigo = Object.fromEntries(res.body.data.map((p) => [p.code, p.priceMissing]));

    expect(porCodigo).toEqual({ 'CON-PRE': false, 'SIN-PRE': true });
  });

  it('test_las_alertas_de_stock_incluyen_los_campos_de_precio_para_el_administrador', async () => {
    await createPart(admin.id, { code: 'ALE-001', stock: 1, minStock: 3, salePrice: 70, purchasePrice: 40 });

    const res = await request(app).get('/api/parts/alerts').set(auth(admin.token));

    expect(res.status).toBe(200);
    expect(res.body.data.items[0]).toMatchObject({ code: 'ALE-001', purchasePrice: '40.00', salePrice: '70.00', priceMissing: false });
  });
});

describe('permisos (FR-003)', () => {
  it.each([
    ['recepción', () => recepcion],
    ['mecánico', () => mecanico],
  ])('test_%s_no_puede_crear_ni_editar_precios', async (_nombre, quien) => {
    const parte = await createPart(admin.id, { salePrice: 100 });

    const alta = await crear(datos({ salePrice: 10 }), quien());
    const edicion = await editar(parte.id, { salePrice: 1 }, quien());

    expect(alta.status).toBe(403);
    expect(edicion.status).toBe(403);
    expect((await filaEnBase(parte.id)).sale_price).toBe('100.00');
  });

  it('test_el_mecanico_no_recibe_ningun_precio_en_el_listado', async () => {
    await createPart(admin.id, { code: 'MEC-001', purchasePrice: 40, salePrice: 70, category: 'Frenos', brand: 'X' });

    const res = await request(app).get('/api/parts').set(auth(mecanico.token));

    expect(res.status).toBe(200);
    for (const clave of ['purchasePrice', 'salePrice', 'priceMissing', 'category', 'brand']) {
      expect(res.body.data[0]).not.toHaveProperty(clave);
    }
  });
});
