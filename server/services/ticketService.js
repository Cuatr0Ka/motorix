import { withTransaction } from '../config/db.js';
import { getShopConfig } from '../config/env.js';
import * as orderModel from '../models/orderModel.js';
import * as orderPartModel from '../models/orderPartModel.js';
import * as orderWorkModel from '../models/orderWorkModel.js';
import * as paymentModel from '../models/paymentModel.js';
import * as ticketModel from '../models/ticketModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';
import { buildTicketContent } from './ticketContent.js';

const orderNotFound = () => AppError.notFound('La orden no existe.');
const ticketNotFound = () => AppError.notFound('El ticket no existe.');

/**
 * Genera el ticket de una orden cobrada. Hay a lo sumo uno por orden: si ya existe se devuelve ese (`created: false`).
 * Guarda una instantánea del contenido (taller, cliente, vehículo, conceptos e importes) que no cambia aunque la orden
 * cambie después. La orden se bloquea ANTES de cualquier lectura, así dos generaciones simultáneas se ordenan.
 */
export async function generate(orderId, actor) {
  if (!(await orderModel.findById(orderId))) throw orderNotFound();

  try {
    return await withTransaction(async (connection) => {
      const locked = await orderModel.lockById(orderId, connection);
      if (!locked) throw orderNotFound();

      const existing = await ticketModel.findByOrder(orderId, connection);
      if (existing) return { ticket: existing, created: false };

      const payments = await paymentModel.listByOrder(orderId, connection);
      const paid = payments.find((payment) => payment.status === 'PAGADO');
      if (!paid) {
        throw AppError.conflict('TICKET_REQUIRES_PAYMENT', 'La orden debe estar cobrada (pago Pagado) para generar su ticket.');
      }

      const order = await orderModel.findById(orderId, connection);
      const [vehicle, services, labor, parts] = await Promise.all([
        vehicleModel.findById(order.vehicle.id, connection),
        orderWorkModel.listServices(orderId, connection),
        orderWorkModel.listLabor(orderId, connection),
        orderPartModel.listByOrder(orderId, connection),
      ]);

      const content = buildTicketContent({
        shop: getShopConfig(),
        order,
        customer: { name: vehicle.client.name, phone: vehicle.client.phone },
        vehicle,
        services,
        parts,
        labor,
        payment: { method: paid.method, status: paid.status, paidAt: paid.paidAt, reference: paid.reference },
        now: new Date(),
      });
      const id = await ticketModel.insert({ orderId, paymentId: paid.id, content, generatedBy: actor.id }, connection);
      return { ticket: await ticketModel.findById(id, connection), created: true };
    });
  } catch (error) {
    // Carrera residual: otra solicitud creó el ticket justo antes; se devuelve ese.
    if (error?.code === 'ER_DUP_ENTRY') {
      const existing = await ticketModel.findByOrder(orderId);
      if (existing) return { ticket: existing, created: false };
    }
    throw error;
  }
}

export async function getByOrder(orderId) {
  if (!(await orderModel.findById(orderId))) throw orderNotFound();
  const ticket = await ticketModel.findByOrder(orderId);
  if (!ticket) throw AppError.notFound('La orden todavía no tiene ticket.');
  return ticket;
}

export async function getById(id) {
  const ticket = await ticketModel.findById(id);
  if (!ticket) throw ticketNotFound();
  return ticket;
}

export async function list(filters) {
  return ticketModel.list(filters);
}
