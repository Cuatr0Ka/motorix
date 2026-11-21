import * as serviceTypeModel from '../models/serviceTypeModel.js';
import { AppError } from '../utils/AppError.js';
import { ACTIONS, record } from './auditService.js';

const duplicate = () => AppError.conflict('SERVICE_TYPE_DUPLICATE', 'Ya existe un tipo de servicio con ese nombre.');
const intervalRequired = () =>
  AppError.unprocessable('SERVICE_TYPE_INTERVAL_REQUIRED', 'Indica al menos un intervalo: en días o en kilómetros.');
const notFound = () => AppError.notFound('El tipo de servicio no existe.');

export const list = (filters) => serviceTypeModel.list(filters);

/** Opciones para elegir en una línea de servicio: solo los activos. */
export async function listOptions() {
  const types = await serviceTypeModel.listActive();
  return types.map(({ id, name, intervalDays, intervalKm }) => ({ id, name, intervalDays, intervalKm }));
}

export async function create(data, actor) {
  if (data.intervalDays == null && data.intervalKm == null) throw intervalRequired();
  if (await serviceTypeModel.findByName(data.name)) throw duplicate();
  let id;
  try {
    id = await serviceTypeModel.insert(data);
  } catch (error) {
    // Dos altas simultáneas con el mismo nombre: gana la restricción única de la base.
    if (error?.code === 'ER_DUP_ENTRY') throw duplicate();
    throw error;
  }
  await record({
    actor,
    action: ACTIONS.SERVICE_TYPE_CHANGED,
    entityType: 'service_type',
    entityId: id,
    summary: `Alta del tipo de servicio «${data.name}»`,
  });
  return serviceTypeModel.findById(id);
}

/** Edita nombre, intervalos o estado. Quita un intervalo con `null` siempre que quede al menos uno. */
export async function update(id, data, actor) {
  const current = await serviceTypeModel.findById(id);
  if (!current) throw notFound();

  const intervalDays = data.intervalDays !== undefined ? data.intervalDays : current.intervalDays;
  const intervalKm = data.intervalKm !== undefined ? data.intervalKm : current.intervalKm;
  if (intervalDays == null && intervalKm == null) throw intervalRequired();
  if (data.name !== undefined && (await serviceTypeModel.findByName(data.name, id))) throw duplicate();

  try {
    await serviceTypeModel.update(id, data);
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') throw duplicate();
    throw error;
  }

  const changes = [];
  if (data.name !== undefined && data.name !== current.name) changes.push('nombre');
  if (data.intervalDays !== undefined && data.intervalDays !== current.intervalDays) changes.push('intervalo en días');
  if (data.intervalKm !== undefined && data.intervalKm !== current.intervalKm) changes.push('intervalo en km');
  if (data.active !== undefined && data.active !== current.active) changes.push(data.active ? 'reactivado' : 'desactivado');
  await record({
    actor,
    action: ACTIONS.SERVICE_TYPE_CHANGED,
    entityType: 'service_type',
    entityId: id,
    summary: `Cambio del tipo de servicio «${data.name ?? current.name}»${changes.length > 0 ? `: ${changes.join(', ')}` : ''}`,
  });
  return serviceTypeModel.findById(id);
}
