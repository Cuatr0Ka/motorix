import * as clientModel from '../models/clientModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';

const ownerNotFound = () =>
  AppError.unprocessable('OWNER_NOT_FOUND', 'El propietario seleccionado no existe. Elige un cliente registrado.');
const plateDuplicate = () =>
  AppError.conflict('PLATE_DUPLICATE', 'Ya existe un vehículo con esa placa.');
const vinDuplicate = () =>
  AppError.conflict('VIN_DUPLICATE', 'Ya existe un vehículo con ese número de serie (VIN).');

/** Traduce los errores de la base (condiciones de carrera) a los mismos errores de negocio. */
export function translateDbError(error) {
  if (error?.code === 'ER_DUP_ENTRY') {
    return String(error.message).includes('uq_vehicles_vin') ? vinDuplicate() : plateDuplicate();
  }
  if (error?.code === 'ER_NO_REFERENCED_ROW_2') return ownerNotFound();
  return error;
}

export async function list(filters) {
  return vehicleModel.list(filters);
}

export async function getById(id) {
  const vehicle = await vehicleModel.findById(id);
  if (!vehicle) throw AppError.notFound('El vehículo no existe.');
  return vehicle;
}

const mileageDecrease = () =>
  AppError.unprocessable(
    'MILEAGE_DECREASE',
    'El kilometraje no puede ser menor al registrado. Si es una corrección, confírmala de forma explícita.',
  );

/**
 * Edita un vehículo. Permite cambiar de propietario (debe existir otro cliente) y respeta la regla de
 * kilometraje: no puede disminuir ni borrarse salvo con `mileageCorrection`.
 */
export async function update(id, data) {
  const { mileageCorrection, ...fields } = data;

  const current = await vehicleModel.findById(id);
  if (!current) throw AppError.notFound('El vehículo no existe.');

  if (fields.clientId !== undefined && fields.clientId !== current.client.id) {
    if (!(await clientModel.exists(fields.clientId))) throw ownerNotFound();
  }
  if (fields.licensePlate && (await vehicleModel.findByPlate(fields.licensePlate, id))) throw plateDuplicate();
  if (fields.vin && (await vehicleModel.findByVin(fields.vin, id))) throw vinDuplicate();

  if (fields.currentMileage !== undefined && current.currentMileage !== null) {
    const decreases = fields.currentMileage === null || fields.currentMileage < current.currentMileage;
    if (decreases && !mileageCorrection) throw mileageDecrease();
  }

  try {
    await vehicleModel.update(id, fields);
    return await vehicleModel.findById(id);
  } catch (error) {
    throw translateDbError(error);
  }
}

/** Registra un vehículo. Todo vehículo necesita un propietario existente (RN-1). */
export async function create(data) {
  if (!(await clientModel.exists(data.clientId))) throw ownerNotFound();
  if (await vehicleModel.findByPlate(data.licensePlate)) throw plateDuplicate();
  if (data.vin && (await vehicleModel.findByVin(data.vin))) throw vinDuplicate();

  try {
    const id = await vehicleModel.create(data);
    return await vehicleModel.findById(id);
  } catch (error) {
    throw translateDbError(error);
  }
}
