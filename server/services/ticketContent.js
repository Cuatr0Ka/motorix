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
 * Los importes se suman en centavos enteros. Las refacciones se listan con su cantidad y NO suman importe al
 * total (los precios de refacciones no forman parte del MVP). No incluye datos de tarjeta de ningún tipo.
 *
 * @param {object} datos
 * @param {{name:string,address:string,phone:string}} datos.shop
 * @param {{id:number,entryMileage:number,serviceMileage:?number}} datos.order
 * @param {{name:string,phone:?string}} datos.customer
 * @param {{licensePlate:string,brand:string,model:string,year:number}} datos.vehicle
 * @param {Array<{description:string,amount:string}>} datos.services
 * @param {Array<{code:string,name:string,unit:string,quantity:number}>} datos.parts
 * @param {Array<{description:string,amount:string}>} datos.labor
 * @param {{method:string,status:string,paidAt:?(Date|string),reference:?string}} datos.payment
 * @param {Date} datos.now
 */
export function buildTicketContent({ shop, order, customer, vehicle, services, parts, labor, payment, now }) {
  const line = (item) => ({ description: item.description, amount: formatCents(toCents(item.amount)) });
  const servicesCents = services.reduce((sum, item) => sum + toCents(item.amount), 0);
  const laborCents = labor.reduce((sum, item) => sum + toCents(item.amount), 0);

  return {
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
    parts: parts.map((part) => ({ code: part.code, name: part.name, unit: part.unit, quantity: part.quantity })),
    labor: labor.map(line),
    totals: {
      services: formatCents(servicesCents),
      labor: formatCents(laborCents),
      total: formatCents(servicesCents + laborCents),
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
