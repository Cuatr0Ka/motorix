import { withTransaction } from '../config/db.js';
import { getMaintenanceConfig } from '../config/env.js';
import * as maintenanceModel from '../models/maintenanceModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';
import { presentFullMaintenance, toDateOnly } from './maintenancePresenter.js';
import { assertMaintenanceTarget } from './maintenanceStatus.js';
import { loadOrderForActor } from './orderService.js';

const notEditable = () =>
  AppError.conflict('MAINTENANCE_NOT_EDITABLE', 'El mantenimiento ya fue atendido: no admite cambios.');
const notFound = () => AppError.notFound('El mantenimiento no existe.');

/** Fecha 'YYYY-MM-DD' a Date local a medianoche (para guardarla en una columna DATE sin desfase). */
const toDateValue = (text) => (text ? new Date(`${text}T00:00:00`) : null);

/**
 * Carga el mantenimiento para quien actúa. Solo el administrador y el mecánico de la orden de origen
 * lo modifican; para cualquier otro mecánico responde 404 (igual que una orden ajena).
 */
async function loadForActor(id, actor, connection) {
  const maintenance = await maintenanceModel.findById(id, connection);
  if (!maintenance) throw notFound();
  if (actor.role === 'MECHANIC' && maintenance.mechanicId !== actor.id) throw notFound();
  return maintenance;
}

/**
 * Programa el próximo mantenimiento desde una orden Terminada o Entregada (US2). En una sola
 * transacción: bloquea el vehículo (así dos programaciones simultáneas se ordenan), valida contra el
 * kilometraje actual, marca como Atendido el pendiente anterior y crea el nuevo.
 */
export async function schedule(orderId, data, actor) {
  const order = await loadOrderForActor(orderId, actor);
  if (!['TERMINADO', 'ENTREGADO'].includes(order.status)) {
    throw AppError.conflict(
      'ORDER_NOT_FINISHED',
      'Solo se puede programar el próximo mantenimiento cuando la orden está Terminada o Entregada.',
    );
  }

  const id = await withTransaction(async (connection) => {
    const vehicle = await vehicleModel.lockForUpdate(order.vehicle.id, connection);
    assertMaintenanceTarget({
      dueDate: data.dueDate ?? null,
      dueMileage: data.dueMileage ?? null,
      currentMileage: vehicle.current_mileage,
      today: new Date(),
    });
    await maintenanceModel.attendPendingByVehicle(order.vehicle.id, connection);
    return maintenanceModel.insert(
      {
        vehicleId: order.vehicle.id,
        orderId,
        description: data.description,
        dueDate: toDateValue(data.dueDate),
        dueMileage: data.dueMileage ?? null,
        createdBy: actor.id,
      },
      connection,
    );
  });
  return presentFullMaintenance(await maintenanceModel.findById(id), actor);
}

/**
 * Edita descripción, fecha o kilometraje de un mantenimiento pendiente. Solo se validan los objetivos
 * que cambian (un mantenimiento ya vencido puede cambiar de descripción) y siempre debe quedar al
 * menos uno de los dos.
 */
export async function update(id, data, actor) {
  await withTransaction(async (connection) => {
    await loadForActor(id, actor, connection);
    const locked = await maintenanceModel.lockById(id, connection);
    if (locked.status !== 'PENDIENTE') throw notEditable();
    const current = await maintenanceModel.findById(id, connection);

    const dueDate = data.dueDate !== undefined ? data.dueDate : toDateOnly(current.dueDate);
    const dueMileage = data.dueMileage !== undefined ? data.dueMileage : current.dueMileage;
    const dateChanged = data.dueDate !== undefined && data.dueDate !== toDateOnly(current.dueDate);
    const mileageChanged = data.dueMileage !== undefined && data.dueMileage !== current.dueMileage;

    if (dueDate == null && dueMileage == null) assertMaintenanceTarget({ dueDate: null, dueMileage: null });
    if ((dateChanged && dueDate != null) || (mileageChanged && dueMileage != null)) {
      assertMaintenanceTarget({
        dueDate: dateChanged ? dueDate : null,
        dueMileage: mileageChanged ? dueMileage : null,
        currentMileage: current.vehicle.currentMileage,
        today: new Date(),
      });
    }

    await maintenanceModel.update(
      id,
      {
        description: data.description,
        dueDate: data.dueDate === undefined ? undefined : toDateValue(data.dueDate),
        dueMileage: data.dueMileage,
      },
      connection,
    );
  });
  return presentFullMaintenance(await maintenanceModel.findById(id), actor);
}

/** Marca un mantenimiento pendiente como Atendido (acción explícita y definitiva). */
export async function attend(id, actor) {
  await withTransaction(async (connection) => {
    await loadForActor(id, actor, connection);
    const locked = await maintenanceModel.lockById(id, connection);
    if (locked.status !== 'PENDIENTE') throw notEditable();
    await maintenanceModel.markAttended(id, connection);
  });
  return presentFullMaintenance(await maintenanceModel.findById(id), actor);
}

/** Lista general de mantenimientos con cliente y teléfono (ADMIN y RECEPTIONIST). */
export async function list(filters, actor) {
  const { warnDays, warnKm } = getMaintenanceConfig();
  const pad = (n) => String(n).padStart(2, '0');
  const now = new Date();
  const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  const { items, total } = await maintenanceModel.list({ ...filters, today, warnDays, warnKm });
  return { items: items.map((item) => presentFullMaintenance(item, actor, now)), total };
}
