import bcrypt from 'bcryptjs';
import { getConfig } from '../../config/env.js';
import { query } from '../../config/db.js';
import { signToken } from '../../utils/jwt.js';

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
