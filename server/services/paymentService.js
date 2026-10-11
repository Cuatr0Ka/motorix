import { withTransaction } from '../config/db.js';
import { getGateway } from '../integrations/mercadoPago.js';
import * as orderModel from '../models/orderModel.js';
import * as orderWorkModel from '../models/orderWorkModel.js';
import * as paymentModel from '../models/paymentModel.js';
import { AppError } from '../utils/AppError.js';
import { formatFolio } from '../utils/orderFolio.js';
import {
  PAYABLE_ORDER_STATUSES,
  PAYMENT_METHODS,
  assertAmountMatches,
  assertOrderPayable,
  assertSafeReference,
  assertTransition,
  formatCents,
  initialStatusFor,
  mapProviderStatus,
  toCents,
} from './paymentRules.js';

const orderNotFound = () => AppError.notFound('La orden no existe.');
const paymentNotFound = () => AppError.notFound('El pago no existe.');
const alreadyExists = (active) =>
  AppError.conflict(
    'PAYMENT_ALREADY_EXISTS',
    active
      ? `La orden ya tiene un pago ${active.status === 'PAGADO' ? 'registrado' : 'pendiente'}. Cancela el pago pendiente antes de crear otro.`
      : 'La orden ya tiene un pago vigente.',
    active ? { paymentId: active.id, status: active.status } : undefined,
  );

/**
 * Bloque de cobro de una orden (solo para administración y recepción): total a cobrar, pagos, estado de cobro y
 * ticket. El total se calcula (servicios + mano de obra) y nunca se guarda en la orden.
 */
export async function getBilling(order, connection) {
  const [totals, payments, ticket] = await Promise.all([
    orderWorkModel.totals(order.id, connection),
    paymentModel.listByOrder(order.id, connection),
    paymentModel.findTicketRef(order.id, connection),
  ]);
  const totalCents = toCents(totals.total);
  const active = payments.find((payment) => payment.status === 'PENDIENTE' || payment.status === 'PAGADO') ?? null;
  const paid = payments.find((payment) => payment.status === 'PAGADO') ?? null;
  const collectionStatus = paid ? 'PAGADO' : active ? 'PENDIENTE' : 'SIN_COBRAR';
  return {
    total: formatCents(totalCents),
    paidAmount: paid ? paid.amount : '0.00',
    collectionStatus,
    amountOutdated: active ? toCents(active.amount) !== totalCents : false,
    canCharge: PAYABLE_ORDER_STATUSES.includes(order.status) && totalCents > 0 && !active,
    payments,
    ticket: ticket ? { id: ticket.id, folio: `TK-${String(ticket.id).padStart(6, '0')}` } : null,
  };
}

/** Métodos de pago y si están disponibles (Mercado Pago necesita sus credenciales de pruebas en el entorno). */
export function listMethods() {
  const mercadoPagoReady = getGateway().isConfigured();
  return {
    methods: PAYMENT_METHODS.map((method) =>
      method === 'MERCADO_PAGO' && !mercadoPagoReady
        ? { method, available: false, reason: 'Mercado Pago no está configurado en este entorno.' }
        : { method, available: true },
    ),
  };
}

export async function list(filters) {
  return paymentModel.list(filters);
}

export async function getById(id) {
  const payment = await paymentModel.findById(id);
  if (!payment) throw paymentNotFound();
  return payment;
}

export async function listByOrder(orderId) {
  if (!(await orderModel.findById(orderId))) throw orderNotFound();
  return paymentModel.listByOrder(orderId);
}

/**
 * Registra el pago de una orden por su total vigente (RN-13). Efectivo, tarjeta y transferencia nacen Pagado; Mercado
 * Pago nace Pendiente con un enlace de cobro. La orden se bloquea ANTES de cualquier lectura de la transacción (así dos
 * cobros simultáneos se ordenan) y el índice único de la base es la última defensa.
 */
export async function create(orderId, data, actor) {
  const status = initialStatusFor(data.method);
  assertSafeReference(data.reference);
  const gateway = getGateway();
  if (data.method === 'MERCADO_PAGO' && !gateway.isConfigured()) {
    throw new AppError(503, 'PROVIDER_NOT_CONFIGURED', 'Mercado Pago no está configurado en este entorno.');
  }

  try {
    const paymentId = await withTransaction(async (connection) => {
      const locked = await orderModel.lockById(orderId, connection);
      if (!locked) throw orderNotFound();

      const totals = await orderWorkModel.totals(orderId, connection);
      const totalCents = toCents(totals.total);
      assertOrderPayable({ status: locked.status, totalCents });
      assertAmountMatches({ amountCents: data.amount === undefined ? undefined : toCents(data.amount), totalCents });

      const active = await paymentModel.findActiveByOrder(orderId, connection);
      if (active) throw alreadyExists(active);

      const id = await paymentModel.insert(
        { orderId, amount: formatCents(totalCents), method: data.method, status, reference: data.reference, createdBy: actor.id },
        connection,
      );
      if (data.method === 'MERCADO_PAGO') {
        // Si el proveedor falla, la transacción se revierte y no queda un pago a medias.
        const externalReference = `motorix-pago-${id}`;
        const { checkoutUrl } = await gateway.createCheckout({
          reference: externalReference,
          amount: formatCents(totalCents),
          title: `Orden ${formatFolio(orderId)}`,
        });
        await paymentModel.setCheckout(id, { externalReference, checkoutUrl }, connection);
      }
      return id;
    });
    return await paymentModel.findById(paymentId);
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') throw alreadyExists(null);
    throw error;
  }
}

/**
 * Consulta a Mercado Pago el estado de un pago pendiente y lo refleja (Pagado, Rechazado o sigue Pendiente). Un pago
 * ya resuelto, o que no es de Mercado Pago, se devuelve tal cual sin llamar al proveedor.
 */
export async function refresh(id) {
  const payment = await paymentModel.findById(id);
  if (!payment) throw paymentNotFound();
  if (payment.method !== 'MERCADO_PAGO' || payment.status !== 'PENDIENTE' || !payment.externalReference) return payment;

  const operations = await getGateway().findPaymentByReference(payment.externalReference);
  const resolved = mapProviderStatus(operations);

  await withTransaction(async (connection) => {
    const locked = await paymentModel.lockById(id, connection);
    if (!locked || locked.status !== 'PENDIENTE') return; // otra consulta o cancelación se adelantó
    if (resolved.status === 'PAGADO') {
      assertTransition('PENDIENTE', 'PAGADO');
      await paymentModel.markPaid(id, { externalPaymentId: resolved.operation.id }, connection);
    } else if (resolved.status === 'RECHAZADO') {
      assertTransition('PENDIENTE', 'RECHAZADO');
      await paymentModel.markClosed(id, 'RECHAZADO', connection);
    } else {
      await paymentModel.touchChecked(id, connection);
    }
  });
  return paymentModel.findById(id);
}

/** Cancela un pago pendiente (el pago se conserva en el historial y la orden queda libre para un nuevo cobro). */
export async function cancel(id) {
  await withTransaction(async (connection) => {
    const locked = await paymentModel.lockById(id, connection);
    if (!locked) throw paymentNotFound();
    assertTransition(locked.status, 'CANCELADO');
    await paymentModel.markClosed(id, 'CANCELADO', connection);
  });
  return paymentModel.findById(id);
}
