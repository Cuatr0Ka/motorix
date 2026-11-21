import { query } from '../config/db.js';

// Todas las consultas reciben el periodo ya validado (`startSql` inclusivo y `endSql` exclusivo) y suman en CENTAVOS enteros
// con SUM(ROUND(importe * 100)) para no acumular errores de redondeo. Nada de aquí se pagina: el límite es el periodo de un año.

const num = (value) => Number(value ?? 0);

/** Pagos PAGADO con paid_at en el periodo, por método. */
export async function incomeByMethod({ startSql, endSql }) {
  const rows = await query(
    `SELECT method, COUNT(*) AS payments, SUM(ROUND(amount * 100)) AS cents
       FROM payments
      WHERE status = 'PAGADO' AND paid_at >= ? AND paid_at < ?
      GROUP BY method ORDER BY cents DESC, method ASC`,
    [startSql, endSql],
  );
  return rows.map((row) => ({ method: row.method, payments: num(row.payments), cents: num(row.cents) }));
}

/** Pagos PAGADO con paid_at en el periodo, por día. */
export async function incomeByDay({ startSql, endSql }) {
  const rows = await query(
    `SELECT DATE_FORMAT(paid_at, '%Y-%m-%d') AS day, COUNT(*) AS payments, SUM(ROUND(amount * 100)) AS cents
       FROM payments
      WHERE status = 'PAGADO' AND paid_at >= ? AND paid_at < ?
      GROUP BY day ORDER BY day ASC`,
    [startSql, endSql],
  );
  return rows.map((row) => ({ day: row.day, payments: num(row.payments), cents: num(row.cents) }));
}

// Órdenes terminadas en el periodo: la fecha de «Terminada» es el último cambio a TERMINADO del historial (o updated_at si
// la orden no tiene historial). Entran las órdenes que hoy están Terminadas o Entregadas.
const FINISHED_ORDERS = `
  SELECT o.id, o.mechanic_id,
         COALESCE((SELECT MAX(h.changed_at) FROM order_status_history h WHERE h.order_id = o.id AND h.to_status = 'TERMINADO'), o.updated_at) AS finished_at
    FROM service_orders o
   WHERE o.status IN ('TERMINADO', 'ENTREGADO')`;

/** Servicios de las órdenes terminadas: por tipo si lo tiene y por descripción si no, de mayor a menor frecuencia. */
export async function services({ startSql, endSql }) {
  const rows = await query(
    `SELECT COALESCE(t.name, s.description) AS name, COUNT(*) AS times, SUM(ROUND(s.amount * 100)) AS cents
       FROM (${FINISHED_ORDERS}) f
       JOIN order_services s ON s.order_id = f.id
       LEFT JOIN service_types t ON t.id = s.service_type_id
      WHERE f.finished_at >= ? AND f.finished_at < ?
      GROUP BY COALESCE(t.name, s.description)
      ORDER BY times DESC, cents DESC, name ASC`,
    [startSql, endSql],
  );
  return rows.map((row) => ({ name: row.name, times: num(row.times), cents: num(row.cents) }));
}

/** Por mecánico: órdenes terminadas en el periodo e importe de mano de obra. Una orden sin mecánico no se atribuye a nadie. */
export async function productivity({ startSql, endSql }) {
  const rows = await query(
    `SELECT u.id AS mechanic_id, u.name,
            COUNT(*) AS orders_finished,
            COALESCE(SUM((SELECT SUM(ROUND(l.amount * 100)) FROM order_labor l WHERE l.order_id = f.id)), 0) AS labor_cents
       FROM (${FINISHED_ORDERS}) f
       JOIN users u ON u.id = f.mechanic_id
      WHERE f.finished_at >= ? AND f.finished_at < ?
      GROUP BY u.id, u.name
      ORDER BY orders_finished DESC, labor_cents DESC, u.name ASC`,
    [startSql, endSql],
  );
  return rows.map((row) => ({
    mechanicId: row.mechanic_id,
    name: row.name,
    ordersFinished: num(row.orders_finished),
    laborCents: num(row.labor_cents),
  }));
}

/**
 * Refacciones usadas en órdenes durante el periodo (por la fecha de la línea). Las líneas anteriores al Sprint 5 (precio 0) no
 * entran: distorsionarían el ingreso y el margen. El costo usa el precio de compra ACTUAL de la refacción.
 */
export async function parts({ startSql, endSql }) {
  const rows = await query(
    `SELECT p.id AS part_id, p.code, p.name, p.purchase_price,
            SUM(op.quantity) AS units, SUM(ROUND(op.quantity * op.unit_price * 100)) AS revenue_cents
       FROM order_parts op JOIN parts p ON p.id = op.part_id
      WHERE op.unit_price > 0 AND op.created_at >= ? AND op.created_at < ?
      GROUP BY p.id, p.code, p.name, p.purchase_price
      ORDER BY revenue_cents DESC, p.name ASC`,
    [startSql, endSql],
  );
  return rows.map((row) => ({
    partId: row.part_id,
    code: row.code,
    name: row.name,
    purchasePrice: row.purchase_price === null ? null : Number(row.purchase_price),
    units: num(row.units),
    revenueCents: num(row.revenue_cents),
  }));
}

/**
 * Rotación: salidas (OUT) del periodo y existencia al inicio y al final, reconstruida desde el stock actual y los movimientos
 * posteriores a cada extremo.
 */
export async function rotation({ startSql, endSql }) {
  const rows = await query(
    `SELECT p.id AS part_id, p.code, p.name, p.stock,
            COALESCE(SUM(CASE WHEN m.type = 'OUT' AND m.created_at >= ? AND m.created_at < ? THEN -m.quantity ELSE 0 END), 0) AS out_units,
            COALESCE(SUM(CASE WHEN m.created_at >= ? THEN m.quantity ELSE 0 END), 0) AS moved_since_start,
            COALESCE(SUM(CASE WHEN m.created_at >= ? THEN m.quantity ELSE 0 END), 0) AS moved_since_end
       FROM parts p LEFT JOIN inventory_movements m ON m.part_id = p.id
      GROUP BY p.id, p.code, p.name, p.stock
     HAVING out_units > 0
      ORDER BY out_units DESC, p.name ASC`,
    [startSql, endSql, startSql, endSql],
  );
  return rows.map((row) => ({
    partId: row.part_id,
    code: row.code,
    name: row.name,
    out: num(row.out_units),
    stockStart: num(row.stock) - num(row.moved_since_start),
    stockEnd: num(row.stock) - num(row.moved_since_end),
  }));
}
