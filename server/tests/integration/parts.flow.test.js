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
const datos = (extra = {}) => ({ code: 'FIL-ACE', name: 'Filtro de aceite', unit: 'pieza', minStock: 3, initialStock: 10, ...extra });

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');
});

describe('alta de refacciones (US3, CA-4)', () => {
  it('test_registra_una_refaccion_con_stock_inicial_y_genera_el_movimiento_de_entrada', async () => {
    const res = await crear(datos({ description: 'Filtro estándar' }));

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      code: 'FIL-ACE',
      name: 'Filtro de aceite',
      description: 'Filtro estándar',
      unit: 'pieza',
      stock: 10,
      minStock: 3,
      active: true,
      stockStatus: 'SUFICIENTE',
    });
    const movimientos = await query('SELECT type, quantity, reason FROM inventory_movements WHERE part_id = ?', [res.body.data.id]);
    expect(movimientos).toEqual([{ type: 'IN', quantity: 10, reason: 'Stock inicial' }]);
  });

  it('test_sin_stock_inicial_no_genera_movimiento_y_queda_agotada', async () => {
    const res = await crear(datos({ initialStock: 0 }));

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ stock: 0, stockStatus: 'AGOTADO' });
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM inventory_movements');
    expect(Number(total)).toBe(0);
  });

  it('test_normaliza_el_codigo_a_mayusculas', async () => {
    const res = await crear(datos({ code: ' fil-ace ' }));

    expect(res.body.data.code).toBe('FIL-ACE');
  });

  it('test_rechaza_un_codigo_duplicado_sin_distinguir_mayusculas', async () => {
    await crear(datos());

    const res = await crear(datos({ code: 'fil-ace', name: 'Otro' }));

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PART_CODE_TAKEN');
  });

  it.each([
    [{ code: 'A' }, 'code'],
    [{ code: 'con espacio' }, 'code'],
    [{ name: 'x' }, 'name'],
    [{ unit: '' }, 'unit'],
    [{ minStock: -1 }, 'minStock'],
    [{ initialStock: 1.5 }, 'initialStock'],
    [{ initialStock: 1000001 }, 'initialStock'],
    [{ minStock: '3' }, 'minStock'],
  ])('test_rechaza_con_400_los_datos_%j', async (cambio, campo) => {
    const res = await crear(datos(cambio));

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.field)).toContain(campo);
  });
});

describe('consulta del catálogo', () => {
  beforeEach(async () => {
    await createPart(admin.id, { code: 'AAA-001', name: 'Balatas delanteras', stock: 10, minStock: 3 });
    await createPart(admin.id, { code: 'BBB-002', name: 'Bujía', stock: 2, minStock: 5 });
    await createPart(admin.id, { code: 'CCC-003', name: 'Correa de distribución', stock: 0, minStock: 2 });
    await createPart(admin.id, { code: 'DDD-004', name: 'Disco inactivo', stock: 4, minStock: 1, active: 0 });
  });

  const listar = (user, q = '') => request(app).get(`/api/parts${q}`).set(auth(user.token));
  const codigos = (res) => res.body.data.map((p) => p.code);

  it('test_el_administrador_ve_todo_ordenado_por_nombre', async () => {
    const res = await listar(admin);

    expect(res.status).toBe(200);
    expect(codigos(res)).toEqual(['AAA-001', 'BBB-002', 'CCC-003', 'DDD-004']);
    expect(res.body.meta.total).toBe(4);
    expect(res.body.data[1]).toMatchObject({ stockStatus: 'BAJO', minStock: 5, active: true });
  });

  it('test_busca_por_codigo_o_nombre', async () => {
    expect(codigos(await listar(admin, '?search=bbb'))).toEqual(['BBB-002']);
    expect(codigos(await listar(admin, '?search=correa'))).toEqual(['CCC-003']);
  });

  it('test_filtra_por_estado_de_stock', async () => {
    expect(codigos(await listar(admin, '?stockStatus=SUFICIENTE&active=true'))).toEqual(['AAA-001']);
    expect(codigos(await listar(admin, '?stockStatus=BAJO'))).toEqual(['BBB-002']);
    expect(codigos(await listar(admin, '?stockStatus=AGOTADO'))).toEqual(['CCC-003']);
  });

  it('test_filtra_por_activas_e_inactivas', async () => {
    expect(codigos(await listar(admin, '?active=false'))).toEqual(['DDD-004']);
    expect(await listar(admin, '?active=quizas')).toHaveProperty('status', 400);
  });

  it('test_el_mecanico_solo_ve_activas_con_la_proyeccion_reducida', async () => {
    const res = await listar(mecanico, '?stockStatus=AGOTADO&active=false');

    expect(res.status).toBe(200);
    expect(codigos(res)).toEqual(['AAA-001', 'BBB-002', 'CCC-003']);
    expect(Object.keys(res.body.data[0]).sort()).toEqual(['code', 'id', 'name', 'stock', 'unit']);
  });

  it('test_recepcion_no_puede_consultar_el_catalogo', async () => {
    const res = await listar(recepcion);

    expect(res.status).toBe(403);
  });

  it('test_el_detalle_incluye_los_movimientos_y_es_solo_para_el_administrador', async () => {
    const [{ id }] = await query("SELECT id FROM parts WHERE code = 'AAA-001'");

    const admin200 = await request(app).get(`/api/parts/${id}`).set(auth(admin.token));
    const mecanico403 = await request(app).get(`/api/parts/${id}`).set(auth(mecanico.token));
    const inexistente = await request(app).get('/api/parts/999999').set(auth(admin.token));

    expect(admin200.status).toBe(200);
    expect(admin200.body.data).toMatchObject({ code: 'AAA-001', stock: 10 });
    expect(admin200.body.data.movements).toHaveLength(1);
    expect(mecanico403.status).toBe(403);
    expect(inexistente.status).toBe(404);
  });
});

describe('edición, activación y desactivación', () => {
  let parte;

  beforeEach(async () => {
    parte = await createPart(admin.id, { code: 'EDT-001', name: 'Original', stock: 7, minStock: 2 });
  });

  const editar = (cuerpo, user = admin) => request(app).patch(`/api/parts/${parte.id}`).set(auth(user.token)).send(cuerpo);

  it('test_edita_los_datos_sin_alterar_el_stock_ni_los_movimientos', async () => {
    const res = await editar({ name: 'Nuevo nombre', unit: 'juego', minStock: 4, description: 'Texto' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ name: 'Nuevo nombre', unit: 'juego', minStock: 4, description: 'Texto', stock: 7, code: 'EDT-001' });
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM inventory_movements WHERE part_id = ?', [parte.id]);
    expect(Number(total)).toBe(1);
  });

  it('test_no_permite_cambiar_el_codigo_ni_el_stock', async () => {
    expect((await editar({ code: 'OTRO' })).status).toBe(400);
    expect((await editar({ stock: 99 })).status).toBe(400);
    const [{ stock }] = await query('SELECT stock FROM parts WHERE id = ?', [parte.id]);
    expect(stock).toBe(7);
  });

  it('test_desactiva_y_reactiva_sin_borrar_la_refaccion', async () => {
    const apagada = await editar({ active: false });
    const encendida = await editar({ active: true });

    expect(apagada.body.data.active).toBe(false);
    expect(encendida.body.data.active).toBe(true);
  });

  it('test_rechaza_un_cuerpo_vacio_y_a_quien_no_es_administrador', async () => {
    expect((await editar({})).status).toBe(400);
    expect((await editar({ name: 'Intento' }, mecanico)).status).toBe(403);
    expect((await editar({ name: 'Intento' }, recepcion)).status).toBe(403);
    expect((await request(app).patch('/api/parts/999999').set(auth(admin.token)).send({ name: 'Nada' })).status).toBe(404);
  });

  it('test_no_existen_operaciones_para_eliminar_ni_reemplazar', async () => {
    const borrar = await request(app).delete(`/api/parts/${parte.id}`).set(auth(admin.token));
    const reemplazar = await request(app).put(`/api/parts/${parte.id}`).set(auth(admin.token)).send(datos());

    expect(borrar.status).toBe(404);
    expect(reemplazar.status).toBe(404);
    const [{ total }] = await query('SELECT COUNT(*) AS total FROM parts');
    expect(Number(total)).toBe(1);
  });
});

describe('permisos de alta', () => {
  it.each(['mecanico', 'recepcion'])('test_el_rol_%s_no_puede_registrar_refacciones', async (rol) => {
    const user = rol === 'mecanico' ? mecanico : recepcion;

    const res = await crear(datos(), user);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('test_exige_sesion', async () => {
    const res = await request(app).post('/api/parts').send(datos());

    expect(res.status).toBe(401);
  });
});
