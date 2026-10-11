import { withTransaction } from '../config/db.js';
import * as inventoryMovementModel from '../models/inventoryMovementModel.js';
import * as partModel from '../models/partModel.js';
import { AppError } from '../utils/AppError.js';
import { assertPositiveInteger, assertStockAvailable, computeAdjustmentDelta, signedQuantity } from './stockRules.js';

const partNotFound = () => AppError.notFound('La refacción no existe.');
const partInactive = () =>
  AppError.conflict('PART_INACTIVE', 'La refacción está desactivada: no admite nuevos usos ni entradas.');

/**
 * ÚNICO punto que modifica `parts.stock` y registra movimientos de inventario (research D-05, D-06).
 * Debe llamarse dentro de una transacción (`connection`): bloquea la fila de la refacción, rechaza una
 * salida que dejaría el stock negativo, aplica el cambio con una actualización condicionada e inserta
 * el movimiento. Todo o nada: si algo falla, la transacción completa se revierte.
 *
 * `quantity` lleva signo: entrada (+), salida (−) o ajuste (±, distinto de cero).
 * Devuelve `{ movement, part }` con el estado de la refacción ya actualizado.
 */
export async function registerMovement(connection, { partId, type, quantity, reason, orderId, actorId }) {
  const part = await partModel.lockById(partId, connection);
  if (!part) throw partNotFound();

  if (quantity < 0) assertStockAvailable({ available: part.stock, requested: -quantity });
  const applied = await partModel.applyDelta(partId, quantity, connection);
  if (!applied) {
    // Última defensa: ni con la fila bloqueada se permite un stock negativo.
    assertStockAvailable({ available: part.stock, requested: -quantity });
  }

  const movementId = await inventoryMovementModel.insert(
    { partId, type, quantity, reason, orderId, createdBy: actorId },
    connection,
  );
  return {
    movement: await inventoryMovementModel.findById(movementId, connection),
    part: partModel.toPart(await partModel.findById(partId, connection)),
  };
}

/** Entrada de mercancía (administrador). Rechaza refacciones desactivadas. */
export async function receive(partId, { quantity, reason }, actor) {
  assertPositiveInteger(quantity);
  return withTransaction(async (connection) => {
    const part = await partModel.lockById(partId, connection);
    if (!part) throw partNotFound();
    if (!part.active) throw partInactive();
    return registerMovement(connection, {
      partId,
      type: 'IN',
      quantity: signedQuantity('IN', quantity),
      reason: reason ?? 'Entrada de mercancía',
      actorId: actor.id,
    });
  });
}

/**
 * Ajuste por conteo físico (administrador): el stock queda en la cantidad contada y el movimiento
 * guarda la diferencia, calculada contra el stock vigente con la fila bloqueada.
 */
export async function adjust(partId, { countedQuantity, reason }, actor) {
  return withTransaction(async (connection) => {
    const part = await partModel.lockById(partId, connection);
    if (!part) throw partNotFound();
    const delta = computeAdjustmentDelta({ stock: part.stock, countedQuantity });
    return registerMovement(connection, {
      partId,
      type: 'ADJUSTMENT',
      quantity: delta,
      reason,
      actorId: actor.id,
    });
  });
}
