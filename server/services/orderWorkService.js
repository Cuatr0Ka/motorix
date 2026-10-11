import { withTransaction } from '../config/db.js';
import * as orderModel from '../models/orderModel.js';
import * as orderWorkModel from '../models/orderWorkModel.js';
import { AppError } from '../utils/AppError.js';
import { buildDetail, loadOrderForActor } from './orderService.js';

const readOnly = () =>
  AppError.conflict('ORDER_READ_ONLY', 'La orden está entregada: es de solo lectura y no admite cambios.');
const lineNotFound = () => AppError.notFound('La línea no existe en esta orden.');

/**
 * Carga la orden para quien actúa (el mecánico solo las suyas; una ajena responde 404) y rechaza las
 * órdenes entregadas, que son historial de solo lectura (RN-9).
 */
async function loadEditableOrder(id, actor, connection) {
  const order = await loadOrderForActor(id, actor, connection);
  if (order.status === 'ENTREGADO') throw readOnly();
  return order;
}

/** Registra o edita el diagnóstico, las observaciones y las recomendaciones. Devuelve el detalle. */
export async function updateWork(id, fields, actor) {
  await withTransaction(async (connection) => {
    await loadEditableOrder(id, actor, connection);
    // Se vuelve a leer con bloqueo para que una entrega simultánea no deje pasar la edición.
    const locked = await orderModel.lockById(id, connection);
    if (locked.status === 'ENTREGADO') throw readOnly();
    await orderModel.updateWork(id, fields, connection);
  });
  return buildDetail(await loadOrderForActor(id, actor), actor);
}

/** Alta de una línea de servicio ('services') o de mano de obra ('labor'). */
export async function addLine(kind, orderId, data, actor) {
  return withTransaction(async (connection) => {
    await loadEditableOrder(orderId, actor, connection);
    const locked = await orderModel.lockById(orderId, connection);
    if (locked.status === 'ENTREGADO') throw readOnly();
    const lineId = await orderWorkModel.insertLine(kind, orderId, data, connection);
    return {
      item: await orderWorkModel.findLine(kind, orderId, lineId, connection),
      totals: await orderWorkModel.totals(orderId, connection),
    };
  });
}

/** Corrige descripción o importe de una línea. */
export async function updateLine(kind, orderId, lineId, data, actor) {
  return withTransaction(async (connection) => {
    await loadEditableOrder(orderId, actor, connection);
    const locked = await orderModel.lockById(orderId, connection);
    if (locked.status === 'ENTREGADO') throw readOnly();
    if (!(await orderWorkModel.findLine(kind, orderId, lineId, connection))) throw lineNotFound();
    await orderWorkModel.updateLine(kind, orderId, lineId, data, connection);
    return {
      item: await orderWorkModel.findLine(kind, orderId, lineId, connection),
      totals: await orderWorkModel.totals(orderId, connection),
    };
  });
}

/** Quita una línea. Los totales se recalculan. */
export async function removeLine(kind, orderId, lineId, actor) {
  return withTransaction(async (connection) => {
    await loadEditableOrder(orderId, actor, connection);
    const locked = await orderModel.lockById(orderId, connection);
    if (locked.status === 'ENTREGADO') throw readOnly();
    if (!(await orderWorkModel.findLine(kind, orderId, lineId, connection))) throw lineNotFound();
    await orderWorkModel.deleteLine(kind, orderId, lineId, connection);
    return { deleted: true, totals: await orderWorkModel.totals(orderId, connection) };
  });
}
