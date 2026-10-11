import { query } from '../config/db.js';
import { formatFolio, parseFolioSearch } from '../utils/orderFolio.js';
import { likePattern, limitOffset } from '../utils/pagination.js';
import { formatTicketFolio } from '../services/ticketContent.js';

// Tabla de solo lectura: este módulo no ofrece actualizar ni borrar tickets.

const SELECT = `SELECT t.id, t.order_id, t.payment_id, t.generated_at, u.id AS user_id, u.name AS user_name,
       t.content, c.name AS client_name, v.license_plate
  FROM tickets t
  JOIN service_orders o ON o.id = t.order_id
  JOIN clients c ON c.id = o.client_id
  JOIN vehicles v ON v.id = o.vehicle_id
  JOIN users u ON u.id = t.generated_by`;

/** `content` puede llegar ya como objeto (columna JSON) o como texto, según el controlador. */
const parseContent = (value) => (typeof value === 'string' ? JSON.parse(value) : value);

const toTicket = (row, { withContent }) => {
  const content = parseContent(row.content);
  const ticket = {
    id: row.id,
    folio: formatTicketFolio(row.id),
    orderId: row.order_id,
    orderFolio: formatFolio(row.order_id),
    paymentId: row.payment_id,
    generatedAt: row.generated_at,
    generatedBy: { id: row.user_id, name: row.user_name },
  };
  if (withContent) return { ...ticket, content };
  // En los listados no viaja el contenido completo, solo lo necesario para la tabla.
  return { ...ticket, client: { name: row.client_name }, vehicle: { licensePlate: row.license_plate }, total: content?.totals?.total ?? null };
};

export async function findById(id, connection) {
  const rows = await query(`${SELECT} WHERE t.id = ?`, [id], connection);
  return rows[0] ? toTicket(rows[0], { withContent: true }) : null;
}

export async function findByOrder(orderId, connection) {
  const rows = await query(`${SELECT} WHERE t.order_id = ?`, [orderId], connection);
  return rows[0] ? toTicket(rows[0], { withContent: true }) : null;
}

/** Interpreta «TK-12» o «tk000012» como identificador de ticket (o null). */
function parseTicketFolio(text) {
  const match = String(text).trim().match(/^tk-?0*(\d{1,9})$/i);
  return match ? Number(match[1]) : null;
}

/** Listado paginado, más recientes primero. Busca por folio de ticket, folio de orden, cliente o placa. */
export async function list({ search, page, pageSize }) {
  const conditions = [];
  const params = [];
  if (search) {
    const pattern = likePattern(search);
    const ticketId = parseTicketFolio(search);
    const orderId = parseFolioSearch(search);
    const ids = [];
    if (ticketId) {
      ids.push('t.id = ?');
      params.push(ticketId);
    }
    if (orderId) {
      ids.push('t.order_id = ?');
      params.push(orderId);
    }
    conditions.push(`(${[...ids, 'c.name LIKE ?', 'v.license_plate LIKE ?'].join(' OR ')})`);
    params.push(pattern, pattern);
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const { limit, offset } = limitOffset(page, pageSize);

  const rows = await query(`${SELECT} ${where} ORDER BY t.id DESC LIMIT ${limit} OFFSET ${offset}`, params);
  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM tickets t
       JOIN service_orders o ON o.id = t.order_id
       JOIN clients c ON c.id = o.client_id
       JOIN vehicles v ON v.id = o.vehicle_id ${where}`,
    params,
  );
  return { items: rows.map((row) => toTicket(row, { withContent: false })), total: Number(total) };
}

export async function insert({ orderId, paymentId, content, generatedBy }, connection) {
  const result = await query(
    'INSERT INTO tickets (order_id, payment_id, content, generated_by) VALUES (?, ?, ?, ?)',
    [orderId, paymentId, JSON.stringify(content), generatedBy],
    connection,
  );
  return result.insertId;
}
