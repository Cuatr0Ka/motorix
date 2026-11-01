import { formatCents, toCents } from './paymentRules.js';

/** Folio legible del ticket: `TK-` más el identificador con 6 dígitos (`TK-000012`). */
export function formatTicketFolio(id) {
  return `TK-${String(id).padStart(6, '0')}`;
}

/** Fecha → texto ISO 8601 (o null). */
const iso = (value) => (value ? new Date(value).toISOString() : null);

/**
 * Arma la instantánea del contenido de un ticket (módulo puro, sin acceso a la base). Es lo que se guarda en
 * `tickets.content` y no cambia aunque la orden, el cliente o el vehículo cambien después.
 *
 * Formato versión 2 (Sprint 5): cada refacción lleva cantidad, precio unitario e importe, y los subtotales de servicios,
 * mano de obra y refacciones se suman en centavos enteros. El total es el importe del pago registrado: no se
 * recalcula, así que el ticket siempre dice lo que se cobró. Los tickets anteriores (sin `formatVersion`) no se
 * convierten. No incluye datos de tarjeta ni el precio de compra de ninguna refacción.
 *
 * @param {object} datos
 * @param {{name:string,address:string,phone:string}} datos.shop
 * @param {{id:number,entryMileage:number,serviceMileage:?number}} datos.order
 * @param {{name:string,phone:?string}} datos.customer
 * @param {{licensePlate:string,brand:string,model:string,year:number}} datos.vehicle
 * @param {Array<{description:string,amount:string}>} datos.services
 * @param {Array<{code:string,name:string,unit:string,quantity:number,unitPrice:string,amount:string}>} datos.parts
 * @param {Array<{description:string,amount:string}>} datos.labor
 * @param {{amount:string,method:string,status:string,paidAt:?(Date|string),reference:?string}} datos.payment
 * @param {Date} datos.now
 */
export function buildTicketContent({ shop, order, customer, vehicle, services, parts, labor, payment, now }) {
  const line = (item) => ({ description: item.description, amount: formatCents(toCents(item.amount)) });
  const servicesCents = services.reduce((sum, item) => sum + toCents(item.amount), 0);
  const laborCents = labor.reduce((sum, item) => sum + toCents(item.amount), 0);
  const partsCents = parts.reduce((sum, item) => sum + toCents(item.amount ?? 0), 0);

  return {
    formatVersion: 2,
    shop: { name: shop.name, address: shop.address, phone: shop.phone },
    customer: { name: customer.name, phone: customer.phone ?? null },
    vehicle: {
      plate: vehicle.licensePlate,
      brand: vehicle.brand,
      model: vehicle.model,
      year: vehicle.year,
      // Kilometraje del servicio si se registró; si no, el de entrada.
      mileage: order.serviceMileage ?? order.entryMileage,
    },
    order: {
      folio: `OS-${String(order.id).padStart(6, '0')}`,
      entryMileage: order.entryMileage,
      serviceMileage: order.serviceMileage ?? null,
    },
    services: services.map(line),
    parts: parts.map((part) => ({
      code: part.code,
      name: part.name,
      unit: part.unit,
      quantity: part.quantity,
      unitPrice: formatCents(toCents(part.unitPrice ?? 0)),
      amount: formatCents(toCents(part.amount ?? 0)),
    })),
    labor: labor.map(line),
    totals: {
      services: formatCents(servicesCents),
      labor: formatCents(laborCents),
      parts: formatCents(partsCents),
      total: formatCents(toCents(payment.amount)),
    },
    payment: {
      method: payment.method,
      status: payment.status,
      paidAt: iso(payment.paidAt),
      reference: payment.reference ?? null,
    },
    generatedAt: iso(now),
  };
}
