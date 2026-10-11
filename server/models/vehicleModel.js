import { query } from '../config/db.js';
import { toCamel } from '../utils/normalize.js';
import { likePattern, limitOffset } from '../utils/pagination.js';

const toVehicleBase = (row) => ({
  id: row.id,
  brand: row.brand,
  model: row.model,
  year: row.year,
  licensePlate: row.license_plate,
  vin: row.vin,
  color: row.color,
  currentMileage: row.current_mileage,
});

/** Listado paginado con búsqueda por placa, marca, modelo o propietario, y filtro por cliente. */
export async function list({ search, clientId, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    conditions.push('(v.license_plate LIKE ? OR v.brand LIKE ? OR v.model LIKE ? OR c.name LIKE ?)');
    params.push(pattern, pattern, pattern, pattern);
  }
  if (clientId) {
    conditions.push('v.client_id = ?');
    params.push(clientId);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(
    `SELECT v.id, v.brand, v.model, v.year, v.license_plate, v.vin, v.color, v.current_mileage,
            c.id AS owner_id, c.name AS owner_name
       FROM vehicles v
       JOIN clients c ON c.id = v.client_id
       ${where}
      ORDER BY v.brand ASC, v.model ASC, v.license_plate ASC, v.id ASC
      LIMIT ${limit} OFFSET ${offset}`,
    params,
  );
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM vehicles v JOIN clients c ON c.id = v.client_id ${where}`,
    params,
  );

  return {
    items: rows.map((row) => ({ ...toVehicleBase(row), client: { id: row.owner_id, name: row.owner_name } })),
    total: Number(total),
  };
}

/** Vehículo con los datos de su propietario (o null si no existe). */
export async function findById(id, connection) {
  const rows = await query(
    `SELECT v.id, v.brand, v.model, v.year, v.license_plate, v.vin, v.color, v.current_mileage,
            v.client_id, c.name AS owner_name, c.phone AS owner_phone
       FROM vehicles v
       JOIN clients c ON c.id = v.client_id
      WHERE v.id = ?`,
    [id],
    connection,
  );
  const row = rows[0];
  if (!row) return null;
  return {
    ...toVehicleBase(row),
    client: { id: row.client_id, name: row.owner_name, phone: row.owner_phone },
  };
}

export async function findByPlate(licensePlate, excludeId = 0) {
  const rows = await query('SELECT id FROM vehicles WHERE license_plate = ? AND id <> ? LIMIT 1', [
    licensePlate,
    excludeId,
  ]);
  return rows[0] ?? null;
}

export async function findByVin(vin, excludeId = 0) {
  const rows = await query('SELECT id FROM vehicles WHERE vin = ? AND id <> ? LIMIT 1', [vin, excludeId]);
  return rows[0] ?? null;
}

export async function create({ clientId, brand, model, year, licensePlate, vin, color, currentMileage }) {
  const result = await query(
    `INSERT INTO vehicles (client_id, brand, model, year, license_plate, vin, color, current_mileage)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [clientId, brand, model, year, licensePlate, vin ?? null, color ?? null, currentMileage ?? null],
  );
  return result.insertId;
}

// Columnas editables (lista blanca: nunca se arma SQL con nombres recibidos del exterior).
const EDITABLE_COLUMNS = {
  clientId: 'client_id',
  brand: 'brand',
  model: 'model',
  year: 'year',
  licensePlate: 'license_plate',
  vin: 'vin',
  color: 'color',
  currentMileage: 'current_mileage',
};

/** Actualiza solo los campos presentes en `fields`. Devuelve true si se envió algún cambio. */
export async function update(id, fields) {
  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(EDITABLE_COLUMNS)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      params.push(fields[key]);
    }
  }
  if (assignments.length === 0) return false;
  await query(`UPDATE vehicles SET ${assignments.join(', ')} WHERE id = ?`, [...params, id]);
  return true;
}

export { toCamel };

/** Bloquea la fila del vehículo dentro de una transacción y devuelve lo necesario para validar una orden. */
export async function lockForUpdate(id, connection) {
  const rows = await query(
    'SELECT id, client_id, current_mileage FROM vehicles WHERE id = ? FOR UPDATE',
    [id],
    connection,
  );
  return rows[0] ?? null;
}

/** Actualiza el kilometraje actual del vehículo (dentro de la transacción de la orden). */
export async function setMileage(id, mileage, connection) {
  await query('UPDATE vehicles SET current_mileage = ? WHERE id = ?', [mileage, id], connection);
}
