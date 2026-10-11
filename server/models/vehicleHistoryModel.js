import { query } from '../config/db.js';
import { formatFolio } from '../utils/orderFolio.js';
import { limitOffset } from '../utils/pagination.js';
import { fromCents, toCents } from './orderWorkModel.js';

const FINISHED = "('TERMINADO','ENTREGADO')";

/** Placeholders `?, ?, ?` para una lista de ids ya validados. */
const placeholders = (ids) => ids.map(() => '?').join(', ');

const toMoneyLine = (row) => ({ description: row.description, amount: fromCents(toCents(row.amount)) });

/**
 * Órdenes terminadas o entregadas del vehículo, de la más reciente a la más antigua (RN-10: el
 * historial se deriva de las órdenes, no se guarda aparte). La fecha del servicio es la del paso a
 * Terminado y, si no existe, la de creación de la orden.
 */
export async function listFinishedOrders(vehicleId, { page, pageSize }) {
  const { limit, offset } = limitOffset(page, pageSize);
  const rows = await query(
    `SELECT o.id, o.status, o.reported_problem, o.diagnosis, o.entry_mileage, o.service_mileage,
            o.mechanic_id, u.name AS mechanic_name,
            COALESCE((SELECT MAX(h.changed_at) FROM order_status_history h
                       WHERE h.order_id = o.id AND h.to_status = 'TERMINADO'), o.created_at) AS service_date
       FROM service_orders o
       LEFT JOIN users u ON u.id = o.mechanic_id
      WHERE o.vehicle_id = ? AND o.status IN ${FINISHED}
      ORDER BY service_date DESC, o.id DESC
      LIMIT ${limit} OFFSET ${offset}`,
    [vehicleId],
  );
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM service_orders WHERE vehicle_id = ? AND status IN ${FINISHED}`,
    [vehicleId],
  );
  return {
    items: rows.map((row) => ({
      orderId: row.id,
      folio: formatFolio(row.id),
      status: row.status,
      serviceDate: row.service_date,
      mileage: row.service_mileage ?? row.entry_mileage,
      reportedProblem: row.reported_problem,
      diagnosis: row.diagnosis,
      mechanic: row.mechanic_id ? { id: row.mechanic_id, name: row.mechanic_name } : null,
    })),
    total: Number(total),
  };
}

/**
 * Servicios, mano de obra, refacciones y mantenimiento programado de varias órdenes, en cuatro
 * consultas (sin una consulta por orden). Devuelve mapas por id de orden.
 */
export async function loadDetails(orderIds) {
  const result = { services: new Map(), labor: new Map(), parts: new Map(), maintenance: new Map() };
  if (orderIds.length === 0) return result;
  const marks = placeholders(orderIds);

  const push = (map, key, value) => {
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(value);
  };

  for (const row of await query(
    `SELECT order_id, description, amount FROM order_services WHERE order_id IN (${marks}) ORDER BY id ASC`,
    orderIds,
  )) {
    push(result.services, row.order_id, toMoneyLine(row));
  }
  for (const row of await query(
    `SELECT order_id, description, amount FROM order_labor WHERE order_id IN (${marks}) ORDER BY id ASC`,
    orderIds,
  )) {
    push(result.labor, row.order_id, toMoneyLine(row));
  }
  for (const row of await query(
    `SELECT op.order_id, op.quantity, p.id AS part_id, p.code, p.name, p.unit
       FROM order_parts op JOIN parts p ON p.id = op.part_id
      WHERE op.order_id IN (${marks}) ORDER BY op.id ASC`,
    orderIds,
  )) {
    push(result.parts, row.order_id, {
      partId: row.part_id,
      code: row.code,
      name: row.name,
      unit: row.unit,
      quantity: row.quantity,
    });
  }
  // Si una orden programó varios mantenimientos, el último (mayor id) es el que se muestra.
  for (const row of await query(
    `SELECT id, order_id, description, due_date, due_mileage, status, attended_at
       FROM maintenance WHERE order_id IN (${marks}) ORDER BY id ASC`,
    orderIds,
  )) {
    result.maintenance.set(row.order_id, {
      id: row.id,
      description: row.description,
      dueDate: row.due_date,
      dueMileage: row.due_mileage,
      status: row.status,
      attendedAt: row.attended_at,
    });
  }
  return result;
}
