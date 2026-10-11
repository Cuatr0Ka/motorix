import bcrypt from 'bcryptjs';
import { getConfig } from '../../config/env.js';
import { query } from '../../config/db.js';
import { signToken } from '../../utils/jwt.js';
import { AppError } from '../../utils/AppError.js';

/** Contraseña conocida de las cuentas creadas en pruebas (cumple la política mínima). */
export const TEST_PASSWORD = 'Prueba2026!';

let counter = 0;
const next = () => ++counter;

/** Vacía las tablas de negocio. Aborta si la base no es de pruebas. */
export async function resetDatabase() {
  const { db } = getConfig();
  if (!db.database.endsWith('_test')) {
    throw new Error(`Se canceló el reinicio: "${db.database}" no es una base de pruebas.`);
  }
  await query('DELETE FROM tickets');
  await query('DELETE FROM payments');
  await query('DELETE FROM inventory_movements');
  await query('DELETE FROM order_parts');
  await query('DELETE FROM maintenance');
  await query('DELETE FROM parts');
  await query('DELETE FROM order_status_history');
  await query('DELETE FROM order_labor');
  await query('DELETE FROM order_services');
  await query('DELETE FROM service_orders');
  await query('DELETE FROM appointments');
  await query('DELETE FROM vehicles');
  await query('DELETE FROM clients');
  await query('DELETE FROM users');
}

export async function createUser(overrides = {}) {
  const n = next();
  const data = {
    username: `usuario${n}`,
    name: `Usuario de prueba ${n}`,
    email: `usuario${n}@prueba.local`,
    password: TEST_PASSWORD,
    role: 'RECEPTIONIST',
    active: 1,
    ...overrides,
  };
  // Costo bajo solo en pruebas para que la suite sea rápida.
  const hash = await bcrypt.hash(data.password, 4);
  const result = await query(
    'INSERT INTO users (username, name, email, password_hash, role, active) VALUES (?, ?, ?, ?, ?, ?)',
    [data.username, data.name, data.email, hash, data.role, data.active],
  );
  return { id: result.insertId, ...data };
}

/** Crea un usuario del rol indicado y devuelve el usuario con su token. */
export async function createUserWithToken(role, overrides = {}) {
  const user = await createUser({ role, ...overrides });
  return { ...user, token: signToken(user.id) };
}

export async function createClient(overrides = {}) {
  const n = next();
  const data = {
    name: `Cliente de prueba ${n}`,
    phone: `55${String(10000000 + n).slice(-8)}`,
    email: `cliente${n}@prueba.local`,
    address: null,
    ...overrides,
  };
  const result = await query('INSERT INTO clients (name, phone, email, address) VALUES (?, ?, ?, ?)', [
    data.name,
    data.phone,
    data.email,
    data.address,
  ]);
  return { id: result.insertId, ...data };
}

export async function createVehicle(clientId, overrides = {}) {
  const n = next();
  const data = {
    brand: 'Nissan',
    model: 'Versa',
    year: 2020,
    licensePlate: `TST-${String(n).padStart(3, '0')}-Z`,
    vin: null,
    color: null,
    currentMileage: null,
    ...overrides,
  };
  const result = await query(
    `INSERT INTO vehicles (client_id, brand, model, year, license_plate, vin, color, current_mileage)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [clientId, data.brand, data.model, data.year, data.licensePlate, data.vin, data.color, data.currentMileage],
  );
  return { id: result.insertId, clientId, ...data };
}

export const auth = (token) => ({ Authorization: `Bearer ${token}` });

/** Fecha futura (en horas a partir de ahora) para citas de prueba. */
export const hoursFromNow = (hours) => new Date(Date.now() + hours * 3600 * 1000);

/** Cita de prueba (estado PENDIENTE y fecha futura por defecto). `createdBy` es el id de un usuario. */
export async function createAppointment(clientId, vehicleId, createdBy, overrides = {}) {
  const data = {
    scheduledAt: hoursFromNow(48),
    reason: 'Servicio de mantenimiento',
    notes: null,
    status: 'PENDIENTE',
    ...overrides,
  };
  const result = await query(
    `INSERT INTO appointments (client_id, vehicle_id, scheduled_at, reason, notes, status, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [clientId, vehicleId, data.scheduledAt, data.reason, data.notes, data.status, createdBy],
  );
  return { id: result.insertId, clientId, vehicleId, ...data };
}

/** Orden de prueba: deriva el cliente del vehículo y registra la entrada inicial del historial. */
export async function createOrder(vehicleId, createdBy, overrides = {}) {
  const [vehicle] = await query('SELECT client_id FROM vehicles WHERE id = ?', [vehicleId]);
  const data = {
    mechanicId: null,
    appointmentId: null,
    status: 'RECIBIDO',
    reportedProblem: 'Ruido al frenar',
    entryMileage: 50000,
    diagnosis: null,
    observations: null,
    recommendations: null,
    ...overrides,
  };
  const result = await query(
    `INSERT INTO service_orders (client_id, vehicle_id, appointment_id, mechanic_id, status, reported_problem,
                                 entry_mileage, diagnosis, observations, recommendations, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      vehicle.client_id,
      vehicleId,
      data.appointmentId,
      data.mechanicId,
      data.status,
      data.reportedProblem,
      data.entryMileage,
      data.diagnosis,
      data.observations,
      data.recommendations,
      createdBy,
    ],
  );
  await query('INSERT INTO order_status_history (order_id, from_status, to_status, changed_by) VALUES (?, NULL, ?, ?)', [
    result.insertId,
    'RECIBIDO',
    createdBy,
  ]);
  return { id: result.insertId, clientId: vehicle.client_id, vehicleId, ...data };
}

export async function createService(orderId, overrides = {}) {
  const data = { description: 'Cambio de balatas', amount: '850.00', ...overrides };
  const result = await query('INSERT INTO order_services (order_id, description, amount) VALUES (?, ?, ?)', [
    orderId,
    data.description,
    data.amount,
  ]);
  return { id: result.insertId, orderId, ...data };
}

export async function createLabor(orderId, overrides = {}) {
  const data = { description: 'Mano de obra frenos', amount: '400.00', ...overrides };
  const result = await query('INSERT INTO order_labor (order_id, description, amount) VALUES (?, ?, ?)', [
    orderId,
    data.description,
    data.amount,
  ]);
  return { id: result.insertId, orderId, ...data };
}

/** Vehículo con propietario listo para usar en pruebas de citas y órdenes. */
export async function createClientWithVehicle(vehicleOverrides = {}, clientOverrides = {}) {
  const client = await createClient(clientOverrides);
  const vehicle = await createVehicle(client.id, vehicleOverrides);
  return { client, vehicle };
}

let partCounter = 0;

/** Refacción de prueba. Con `stock` > 0 registra el movimiento de entrada «Stock inicial» (la suma coincide). */
export async function createPart(createdBy, overrides = {}) {
  partCounter += 1;
  const data = {
    code: `REF-${String(partCounter).padStart(4, '0')}-${Date.now().toString(36).toUpperCase()}`,
    name: `Refacción de prueba ${partCounter}`,
    description: null,
    unit: 'pieza',
    stock: 10,
    minStock: 3,
    active: 1,
    ...overrides,
  };
  const result = await query(
    'INSERT INTO parts (code, name, description, unit, stock, min_stock, active) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [data.code, data.name, data.description, data.unit, data.stock, data.minStock, data.active],
  );
  if (data.stock > 0) {
    await query(
      "INSERT INTO inventory_movements (part_id, type, quantity, reason, created_by) VALUES (?, 'IN', ?, 'Stock inicial', ?)",
      [result.insertId, data.stock, createdBy],
    );
  }
  return { id: result.insertId, ...data };
}

/** Movimiento de inventario directo en la base (no modifica el stock de la refacción). */
export async function createMovement(partId, createdBy, overrides = {}) {
  const data = { type: 'IN', quantity: 1, reason: 'Movimiento de prueba', orderId: null, ...overrides };
  const result = await query(
    'INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by) VALUES (?, ?, ?, ?, ?, ?)',
    [partId, data.type, data.quantity, data.reason, data.orderId, createdBy],
  );
  return { id: result.insertId, partId, ...data };
}

/** Línea de refacción de una orden directo en la base (no genera movimiento ni cambia el stock). */
export async function createOrderPart(orderId, partId, createdBy, quantity = 1) {
  const result = await query('INSERT INTO order_parts (order_id, part_id, quantity, created_by) VALUES (?, ?, ?, ?)', [
    orderId,
    partId,
    quantity,
    createdBy,
  ]);
  return { id: result.insertId, orderId, partId, quantity };
}

/** Mantenimiento de prueba (PENDIENTE por defecto, con fecha objetivo dentro de 6 meses). */
export async function createMaintenance(vehicleId, orderId, createdBy, overrides = {}) {
  const data = {
    description: 'Cambio de aceite y filtro',
    dueDate: new Date(Date.now() + 180 * 24 * 3600 * 1000),
    dueMileage: null,
    status: 'PENDIENTE',
    ...overrides,
  };
  const result = await query(
    `INSERT INTO maintenance (vehicle_id, order_id, description, due_date, due_mileage, status, attended_at, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      vehicleId,
      orderId,
      data.description,
      data.dueDate,
      data.dueMileage,
      data.status,
      data.status === 'ATENDIDO' ? new Date() : null,
      createdBy,
    ],
  );
  return { id: result.insertId, vehicleId, orderId, ...data };
}

/**
 * Orden TERMINADO o ENTREGADO con mecánico, un servicio y su historial de estados. Útil para el
 * historial, el kilometraje del servicio y los mantenimientos.
 */
export async function createFinishedOrder(vehicleId, createdBy, mechanicId, overrides = {}) {
  const { status = 'TERMINADO', ...rest } = overrides;
  const order = await createOrder(vehicleId, createdBy, { mechanicId, status, diagnosis: 'Diagnóstico de prueba', ...rest });
  await createService(order.id);
  return order;
}

/** Pago de prueba directo en la base (por defecto efectivo, PAGADO, por el total `1250.00`). */
export async function createPayment(orderId, createdBy, overrides = {}) {
  const data = {
    amount: '1250.00',
    method: 'EFECTIVO',
    status: 'PAGADO',
    reference: null,
    externalReference: null,
    externalPaymentId: null,
    checkoutUrl: null,
    ...overrides,
  };
  const paidAt = data.status === 'PAGADO' ? new Date() : null;
  const result = await query(
    `INSERT INTO payments (order_id, amount, method, status, reference, external_reference, external_payment_id, checkout_url, paid_at, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [orderId, data.amount, data.method, data.status, data.reference, data.externalReference, data.externalPaymentId, data.checkoutUrl, paidAt, createdBy],
  );
  return { id: result.insertId, orderId, ...data };
}

/** Ticket de prueba directo en la base, con un contenido mínimo válido. */
export async function createTicket(orderId, paymentId, createdBy, overrides = {}) {
  const content = overrides.content ?? { order: { folio: `OS-${String(orderId).padStart(6, '0')}` }, totals: { total: '1250.00' } };
  const result = await query('INSERT INTO tickets (order_id, payment_id, content, generated_by) VALUES (?, ?, ?, ?)', [
    orderId,
    paymentId,
    JSON.stringify(content),
    createdBy,
  ]);
  return { id: result.insertId, orderId, paymentId, content };
}

/**
 * Orden TERMINADA lista para cobrar: un servicio de 850.00 y mano de obra de 400.00 (total 1250.00).
 * Devuelve la orden con su total.
 */
export async function createPayableOrder(vehicleId, createdBy, mechanicId, overrides = {}) {
  const order = await createOrder(vehicleId, createdBy, { mechanicId, status: 'TERMINADO', ...overrides });
  await createService(order.id);
  await createLabor(order.id);
  return { ...order, total: '1250.00' };
}

/**
 * Proveedor de pagos simulado para las pruebas (se instala con `setGateway`). Sus respuestas se programan
 * y cuenta las llamadas; nunca sale a internet.
 */
export class FakeGateway {
  constructor({ configured = true } = {}) {
    this.configured = configured;
    this.checkouts = [];
    this.searches = [];
    this.operations = []; // [{ id, status }] más reciente primero
    this.failCheckout = false;
    this.failSearch = false;
  }

  isConfigured() {
    return this.configured;
  }

  async createCheckout({ reference, amount, title }) {
    if (!this.configured) throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'Mercado Pago no está configurado en este entorno.');
    if (this.failCheckout) throw new AppError(502, 'PROVIDER_ERROR', 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.');
    this.checkouts.push({ reference, amount, title });
    return { checkoutUrl: `https://sandbox.mercadopago.simulado/checkout/${reference}` };
  }

  async findPaymentByReference(reference) {
    if (!this.configured) throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'Mercado Pago no está configurado en este entorno.');
    if (this.failSearch) throw new AppError(502, 'PROVIDER_ERROR', 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.');
    this.searches.push(reference);
    return this.operations;
  }
}
