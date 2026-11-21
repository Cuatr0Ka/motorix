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
  createTicket,
  createUserWithToken,
  resetDatabase,
} from '../helpers/factories.js';

const app = createApp();
const RESERVADAS = ['password', 'passwordHash', 'password_hash', 'hash', 'token'];
const COMPRA = ['purchasePrice', 'purchase_price'];

/** Recorre un JSON y devuelve las rutas de las claves prohibidas que encuentre. */
function clavesEncontradas(valor, prohibidas, ruta = '$') {
  if (Array.isArray(valor)) return valor.flatMap((item, i) => clavesEncontradas(item, prohibidas, `${ruta}[${i}]`));
  if (valor && typeof valor === 'object') {
    return Object.entries(valor).flatMap(([clave, contenido]) => [
      ...(prohibidas.includes(clave) ? [`${ruta}.${clave}`] : []),
      ...clavesEncontradas(contenido, prohibidas, `${ruta}.${clave}`),
    ]);
  }
  return [];
}

let usuarios;
let ids;

beforeEach(async () => {
  await resetDatabase();
  usuarios = {
    ADMIN: await createUserWithToken('ADMIN'),
    RECEPTIONIST: await createUserWithToken('RECEPTIONIST'),
    MECHANIC: await createUserWithToken('MECHANIC'),
  };
  const { vehicle } = await createClientWithVehicle({ licensePlate: 'EXP-001-A' });
  const orden = await createPayableOrder(vehicle.id, usuarios.RECEPTIONIST.id, usuarios.MECHANIC.id);
  const parte = await createPart(usuarios.ADMIN.id, { name: 'Balatas', salePrice: '780.00', purchasePrice: '500.00' });
  await createOrderPart(orden.id, parte.id, usuarios.MECHANIC.id, 1, 780);
  const pago = await createPayment(orden.id, usuarios.RECEPTIONIST.id);
  const ticket = await createTicket(orden.id, pago.id, usuarios.RECEPTIONIST.id);
  ids = { orden: orden.id, parte: parte.id, pago: pago.id, ticket: ticket.id };
});

const rutas = () => [
  '/api/users',
  `/api/users/${usuarios.ADMIN.id}`,
  '/api/mechanics',
  '/api/auth/me',
  '/api/parts',
  `/api/parts/${ids.parte}`,
  '/api/orders',
  `/api/orders/${ids.orden}`,
  '/api/payments',
  `/api/payments/${ids.pago}`,
  '/api/tickets',
  `/api/tickets/${ids.ticket}`,
  '/api/settings',
  '/api/service-types',
  '/api/audit-log',
  '/api/terms/current',
  '/api/terms/acceptances',
  '/api/dashboard',
];

describe('exposición de datos sensibles (US10, FR-017)', () => {
  it.each(['ADMIN', 'RECEPTIONIST', 'MECHANIC'])('test_ninguna_respuesta_del_rol_%s_contiene_contrasenas_hashes_ni_tokens', async (rol) => {
    for (const ruta of rutas()) {
      const res = await request(app).get(ruta).set(auth(usuarios[rol].token));
      expect({ ruta, rol, estado: res.status < 500 }).toEqual({ ruta, rol, estado: true });
      expect({ ruta, claves: clavesEncontradas(res.body, RESERVADAS) }).toEqual({ ruta, claves: [] });
    }
  });

  it('test_el_precio_de_compra_solo_aparece_para_el_administrador', async () => {
    const delAdmin = await request(app).get(`/api/parts/${ids.parte}`).set(auth(usuarios.ADMIN.token));
    expect(clavesEncontradas(delAdmin.body, COMPRA).length).toBeGreaterThan(0);

    for (const rol of ['RECEPTIONIST', 'MECHANIC']) {
      for (const ruta of rutas()) {
        const res = await request(app).get(ruta).set(auth(usuarios[rol].token));
        expect({ ruta, rol, claves: clavesEncontradas(res.body, COMPRA) }).toEqual({ ruta, rol, claves: [] });
      }
    }
  });

  it('test_el_inicio_de_sesion_es_el_unico_que_devuelve_token_y_nunca_el_hash', async () => {
    const res = await request(app).post('/api/auth/login').send({ identifier: usuarios.ADMIN.username, password: usuarios.ADMIN.password });

    expect(res.status).toBe(200);
    expect(clavesEncontradas(res.body, ['password', 'passwordHash', 'password_hash', 'hash'])).toEqual([]);
    expect(res.body.data.token).toEqual(expect.any(String));
  });
});
