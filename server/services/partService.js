import { withTransaction } from '../config/db.js';
import * as inventoryMovementModel from '../models/inventoryMovementModel.js';
import * as partModel from '../models/partModel.js';
import { AppError } from '../utils/AppError.js';
import { registerMovement } from './inventoryService.js';

const partNotFound = () => AppError.notFound('La refacción no existe.');
const codeTaken = () => AppError.conflict('PART_CODE_TAKEN', 'Ya existe una refacción con ese código.');

/**
 * Listado del catálogo. El administrador recibe la vista completa con todos los filtros; el mecánico
 * solo las activas y con la proyección reducida (código, nombre, unidad y existencia).
 */
export async function list(filters, actor) {
  if (actor.role === 'MECHANIC') {
    const { rows, total } = await partModel.list({ ...filters, stockStatus: undefined, active: true });
    return { items: rows.map(partModel.toMechanicPart), total };
  }
  const { rows, total } = await partModel.list(filters);
  return { items: rows.map(partModel.toPart), total };
}

/** Detalle con los últimos movimientos (administrador). */
export async function getById(id) {
  const row = await partModel.findById(id);
  if (!row) throw partNotFound();
  const { items } = await inventoryMovementModel.listByPart(id, { page: 1, pageSize: 10 });
  return { ...partModel.toPart(row), movements: items };
}

/**
 * Alta de refacción. Si trae stock inicial, crea el movimiento de entrada «Stock inicial» en la misma
 * transacción. El código se guarda en mayúsculas y es único.
 */
export async function create(data, actor) {
  try {
    const id = await withTransaction(async (connection) => {
      const partId = await partModel.insert(data, connection);
      if (data.initialStock > 0) {
        await registerMovement(connection, {
          partId,
          type: 'IN',
          quantity: data.initialStock,
          reason: 'Stock inicial',
          actorId: actor.id,
        });
      }
      return partId;
    });
    return partModel.toPart(await partModel.findById(id));
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') throw codeTaken();
    throw error;
  }
}

/** Edita nombre, descripción, unidad, stock mínimo o estado activo; el stock solo cambia con movimientos. */
export async function update(id, fields) {
  const row = await partModel.findById(id);
  if (!row) throw partNotFound();
  await partModel.update(id, fields);
  return partModel.toPart(await partModel.findById(id));
}

export async function listMovements(partId, { page, pageSize }) {
  if (!(await partModel.findById(partId))) throw partNotFound();
  return inventoryMovementModel.listByPart(partId, { page, pageSize });
}

/** Alertas de stock bajo (administrador): conteo, cuántas están agotadas y la lista con stock y mínimo. */
export async function alerts() {
  const rows = await partModel.listAlerts();
  const items = rows.map(partModel.toPart);
  return { count: items.length, outOfStock: items.filter((item) => item.stockStatus === 'AGOTADO').length, items };
}
