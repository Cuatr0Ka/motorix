import { withTransaction } from '../config/db.js';
import * as orderModel from '../models/orderModel.js';
import * as orderPartModel from '../models/orderPartModel.js';
import * as partModel from '../models/partModel.js';
import { AppError } from '../utils/AppError.js';
import { formatFolio } from '../utils/orderFolio.js';
import { registerMovement } from './inventoryService.js';
import { loadOrderForActor } from './orderService.js';
import { assertPositiveInteger, signedQuantity } from './stockRules.js';

const readOnly = () =>
  AppError.conflict('ORDER_READ_ONLY', 'La orden está entregada: es de solo lectura y no admite cambios.');
const partNotFound = () => AppError.notFound('La refacción no existe.');
const lineNotFound = () => AppError.notFound('La refacción no está en esta orden.');
const partInactive = () =>
  AppError.conflict('PART_INACTIVE', 'La refacción está desactivada: no se puede usar en nuevas órdenes.');

/**
 * Bloquea la orden para serializar los cambios y rechaza las entregadas (solo lectura, RN-9). Las
 * refacciones se pueden modificar hasta Terminado inclusive. SIEMPRE se bloquea primero la orden y
 * después la refacción, en ese orden, para no provocar interbloqueos. El bloqueo se toma ANTES de
 * cualquier lectura normal de la transacción: así las lecturas posteriores ven lo que confirmaron las
 * solicitudes que esperaban el mismo bloqueo (nivel REPEATABLE READ).
 */
async function lockEditableOrder(orderId, connection) {
  const locked = await orderModel.lockById(orderId, connection);
  if (!locked) throw AppError.notFound('La orden no existe.');
  if (locked.status === 'ENTREGADO') throw readOnly();
}

/**
 * Agrega una refacción a la orden (RN-6): suma sobre la línea existente si ya estaba y genera la salida
 * de inventario ligada a la orden en la misma transacción (RN-7). Si no hay stock suficiente no cambia nada.
 */
export async function add(orderId, { partId, quantity }, actor) {
  assertPositiveInteger(quantity);
  // La pertenencia se comprueba fuera de la transacción (una orden ajena responde 404 al mecánico).
  const order = await loadOrderForActor(orderId, actor);
  return withTransaction(async (connection) => {
    await lockEditableOrder(orderId, connection);
    const part = await partModel.lockById(partId, connection);
    if (!part) throw partNotFound();
    if (!part.active) throw partInactive();

    const { part: updatedPart } = await registerMovement(connection, {
      partId,
      type: 'OUT',
      quantity: -quantity,
      reason: `Uso en ${order.folio}`,
      orderId,
      actorId: actor.id,
    });

    const existing = await orderPartModel.findByOrderAndPart(orderId, partId, connection);
    if (existing) {
      await orderPartModel.updateQuantity(existing.id, existing.quantity + quantity, connection);
    } else {
      await orderPartModel.insert({ orderId, partId, quantity, createdBy: actor.id }, connection);
    }
    return {
      item: await orderPartModel.findByOrderAndPart(orderId, partId, connection),
      part: updatedPart,
    };
  });
}

/**
 * Corrige la cantidad total de una línea. Si aumenta, genera una salida por la diferencia (y exige
 * stock suficiente); si disminuye, una entrada de devolución. Así el stock refleja siempre el uso real.
 */
export async function updateQuantity(orderId, lineId, quantity, actor) {
  assertPositiveInteger(quantity);
  const order = await loadOrderForActor(orderId, actor);
  return withTransaction(async (connection) => {
    await lockEditableOrder(orderId, connection);
    const line = await orderPartModel.findLine(orderId, lineId, connection);
    if (!line) throw lineNotFound();

    const delta = quantity - line.quantity;
    let updatedPart;
    if (delta !== 0) {
      const part = await partModel.lockById(line.partId, connection);
      if (delta > 0 && !part.active) throw partInactive();
      ({ part: updatedPart } = await registerMovement(connection, {
        partId: line.partId,
        type: delta > 0 ? 'OUT' : 'IN',
        quantity: signedQuantity(delta > 0 ? 'OUT' : 'IN', Math.abs(delta)),
        reason: delta > 0 ? `Uso en ${order.folio}` : `Devolución desde ${order.folio}`,
        orderId,
        actorId: actor.id,
      }));
      await orderPartModel.updateQuantity(lineId, quantity, connection);
    } else {
      updatedPart = partModel.toPart(await partModel.findById(line.partId, connection));
    }
    return { item: await orderPartModel.findLine(orderId, lineId, connection), part: updatedPart };
  });
}

/** Quita la línea y devuelve su cantidad al inventario con una entrada ligada a la orden. */
export async function remove(orderId, lineId, actor) {
  await loadOrderForActor(orderId, actor);
  return withTransaction(async (connection) => {
    await lockEditableOrder(orderId, connection);
    const line = await orderPartModel.findLine(orderId, lineId, connection);
    if (!line) throw lineNotFound();

    await partModel.lockById(line.partId, connection);
    const { part } = await registerMovement(connection, {
      partId: line.partId,
      type: 'IN',
      quantity: line.quantity,
      reason: `Devolución desde ${formatFolio(orderId)}`,
      orderId,
      actorId: actor.id,
    });
    await orderPartModel.deleteLine(lineId, connection);
    return { deleted: true, part };
  });
}
