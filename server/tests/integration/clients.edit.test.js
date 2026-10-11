import request from 'supertest';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClient, createUserWithToken, resetDatabase } from '../helpers/factories.js';

const app = createApp();
let recepcion;
let ana;

const patch = (id, body) => request(app).patch(`/api/clients/${id}`).set(auth(recepcion.token)).send(body);
const detalle = async (id) => (await request(app).get(`/api/clients/${id}`).set(auth(recepcion.token))).body.data;

beforeEach(async () => {
  await resetDatabase();
  recepcion = await createUserWithToken('RECEPTIONIST');
  ana = await createClient({ name: 'Ana Morales', phone: '5511112222', email: 'ana@x.local', address: 'Calle 1' });
});

describe('edición válida', () => {
  it('test_el_nuevo_telefono_se_ve_en_el_detalle_y_en_el_listado', async () => {
    await patch(ana.id, { phone: '5599998888' });

    expect((await detalle(ana.id)).phone).toBe('5599998888');
    const lista = await request(app).get('/api/clients?search=5599998888').set(auth(recepcion.token));
    expect(lista.body.data.map((c) => c.id)).toEqual([ana.id]);
    const antiguo = await request(app).get('/api/clients?search=5511112222').set(auth(recepcion.token));
    expect(antiguo.body.data).toEqual([]);
  });

  it('test_se_pueden_vaciar_el_correo_y_la_direccion_enviando_vacio_o_nulo', async () => {
    const res = await patch(ana.id, { email: '', address: null });

    expect(res.status).toBe(200);
    expect(res.body.data.email).toBeNull();
    expect(res.body.data.address).toBeNull();
  });

  it('test_normaliza_el_correo_a_minusculas_y_recorta_los_textos', async () => {
    const res = await patch(ana.id, { email: '  ANA.NUEVA@X.local ', address: '  Av. 5  ' });

    expect(res.body.data.email).toBe('ana.nueva@x.local');
    expect(res.body.data.address).toBe('Av. 5');
  });

  it('test_actualizar_actualiza_la_fecha_de_modificacion', async () => {
    const [antes] = await query('SELECT updated_at FROM clients WHERE id = ?', [ana.id]);
    await new Promise((resolve) => setTimeout(resolve, 1100));

    await patch(ana.id, { name: 'Ana M.' });

    const [despues] = await query('SELECT updated_at FROM clients WHERE id = ?', [ana.id]);
    expect(new Date(despues.updated_at).getTime()).toBeGreaterThan(new Date(antes.updated_at).getTime());
  });
});

describe('edición inválida no modifica nada', () => {
  it('test_una_edicion_con_datos_invalidos_conserva_los_datos_anteriores', async () => {
    const res = await patch(ana.id, { name: 'Nombre nuevo', phone: 'abc' });

    expect(res.status).toBe(400);
    const actual = await detalle(ana.id);
    expect(actual.name).toBe('Ana Morales');
    expect(actual.phone).toBe('5511112222');
  });

  it('test_una_edicion_rechazada_por_correo_duplicado_no_cambia_ningun_campo', async () => {
    await createClient({ email: 'ocupado@x.local' });

    const res = await patch(ana.id, { name: 'Nombre nuevo', email: 'ocupado@x.local' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_DUPLICATE');
    expect((await detalle(ana.id)).name).toBe('Ana Morales');
  });
});

describe('reglas de duplicados al editar', () => {
  it('test_conservar_el_propio_correo_no_cuenta_como_duplicado', async () => {
    const res = await patch(ana.id, { email: 'ANA@x.local', name: 'Ana M.' });

    expect(res.status).toBe(200);
  });

  it('test_conservar_el_propio_telefono_no_pide_confirmacion', async () => {
    const res = await patch(ana.id, { phone: '55 1111-2222', name: 'Ana M.' });

    expect(res.status).toBe(200);
  });

  it('test_cambiar_a_un_telefono_de_otro_cliente_responde_409_con_coincidencias_y_no_guarda', async () => {
    const luis = await createClient({ name: 'Luis Pérez', phone: '5533334444' });

    const res = await patch(ana.id, { phone: '(55) 3333-4444' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PHONE_DUPLICATE');
    expect(res.body.error.details.matches).toEqual([{ id: luis.id, name: 'Luis Pérez', phone: '5533334444' }]);
    expect((await detalle(ana.id)).phone).toBe('5511112222');
  });

  it('test_el_telefono_de_otro_cliente_se_guarda_si_se_confirma', async () => {
    await createClient({ name: 'Luis Pérez', phone: '5533334444' });

    const res = await patch(ana.id, { phone: '5533334444', confirmDuplicatePhone: true });

    expect(res.status).toBe(200);
    expect(res.body.data.phone).toBe('5533334444');
  });

  it('test_la_coincidencia_de_telefono_nunca_incluye_al_propio_cliente', async () => {
    await createClient({ name: 'Luis Pérez', phone: '5533334444' });

    const res = await patch(ana.id, { phone: '5533334444' });

    expect(res.body.error.details.matches.map((m) => m.id)).not.toContain(ana.id);
  });

  it('test_el_correo_de_otro_cliente_nunca_se_puede_confirmar', async () => {
    await createClient({ email: 'ocupado@x.local' });

    const res = await patch(ana.id, { email: 'ocupado@x.local', confirmDuplicatePhone: true });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_DUPLICATE');
  });

  it('test_no_se_envia_la_bandera_de_confirmacion_al_guardar_ni_se_devuelve', async () => {
    const res = await patch(ana.id, { name: 'Ana M.', confirmDuplicatePhone: true });

    expect(res.body.data.confirmDuplicatePhone).toBeUndefined();
  });
});
