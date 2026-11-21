import { withTransaction } from '../config/db.js';
import * as inventoryMovementModel from '../models/inventoryMovementModel.js';
import * as partModel from '../models/partModel.js';
import { AppError } from '../utils/AppError.js';
import { registerMovement } from './inventoryService.js';
import { ACTIONS, record as recordAudit } from './auditService.js';

const partNotFound = () => AppError.notFound('La refacción no existe.');
const codeTaken = () => AppError.conflict('PART_CODE_TAKEN', 'Ya existe una refacción con ese código.');

const toCents = (amount) => Math.round(Number(amount) * 100);

/**
 * Una venta por debajo del costo se permite solo con la confirmación explícita del administrador (FR-025). Recibe los
 * precios resultantes (cadenas con dos decimales o null) y no hace nada si falta alguno o la venta no es menor.
 */
function assertBelowCostConfirmed({ salePrice, purchasePrice, confirmBelowCost }) {
  if (salePrice == null || purchasePrice == null) return;
  if (toCents(salePrice) >= toCents(purchasePrice) || confirmBelowCost === true) return;
  throw AppError.unprocessable(
    'PRICE_BELOW_COST',
    'El precio de venta es menor al de compra. Confirma para guardarlo.',
    { salePrice, purchasePrice },
  );
}

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
export async function create({ confirmBelowCost, ...data }, actor) {
  assertBelowCostConfirmed({ salePrice: data.salePrice, purchasePrice: data.purchasePrice, confirmBelowCost });
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

/**
 * Edita nombre, descripción, unidad, stock mínimo, estado activo, categoría, marca o precios; el stock solo cambia con
 * movimientos. La confirmación de venta bajo el costo solo se exige cuando el cuerpo trae un precio: editar otros
 * datos de una refacción que ya está bajo el costo no la pide.
 */
export async function update(id, { confirmBelowCost, ...fields }, actor) {
  const row = await partModel.findById(id);
  if (!row) throw partNotFound();
  if (fields.salePrice !== undefined || fields.purchasePrice !== undefined) {
    assertBelowCostConfirmed({
      salePrice: fields.salePrice !== undefined ? fields.salePrice : row.sale_price,
      purchasePrice: fields.purchasePrice !== undefined ? fields.purchasePrice : row.purchase_price,
      confirmBelowCost,
    });
  }
  await partModel.update(id, fields);
  await recordPriceChange(row, fields, actor);
  return partModel.toPart(await partModel.findById(id));
}

/** Bitácora del cambio de precio: solo si cambia el precio de compra o el de venta (con el valor anterior y el nuevo). */
async function recordPriceChange(row, fields, actor) {
  const money = (value) => Number(value).toFixed(2);
  const changes = [];
  if (fields.salePrice !== undefined && money(fields.salePrice) !== money(row.sale_price)) {
    changes.push(`venta ${money(row.sale_price)} → ${money(fields.salePrice)}`);
  }
  if (fields.purchasePrice !== undefined && money(fields.purchasePrice) !== money(row.purchase_price)) {
    changes.push(`compra ${money(row.purchase_price)} → ${money(fields.purchasePrice)}`);
  }
  if (changes.length === 0) return;
  await recordAudit({
    actor,
    action: ACTIONS.PART_PRICE_CHANGED,
    entityType: 'part',
    entityId: row.id,
    summary: `${row.name}: ${changes.join(', ')}`,
  });
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
