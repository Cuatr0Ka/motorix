import * as maintenanceModel from '../models/maintenanceModel.js';
import * as vehicleHistoryModel from '../models/vehicleHistoryModel.js';
import * as vehicleModel from '../models/vehicleModel.js';
import { AppError } from '../utils/AppError.js';
import { presentMaintenance } from './maintenancePresenter.js';

/** Historial del vehículo (todos los roles): órdenes terminadas o entregadas, la más reciente primero. */
export async function getHistory(vehicleId, { page, pageSize }) {
  const vehicle = await vehicleModel.findById(vehicleId);
  if (!vehicle) throw AppError.notFound('El vehículo no existe.');

  const { items, total } = await vehicleHistoryModel.listFinishedOrders(vehicleId, { page, pageSize });
  const details = await vehicleHistoryModel.loadDetails(items.map((item) => item.orderId));
  const pending = await maintenanceModel.findPendingByVehicle(vehicleId);

  const entries = items.map((item) => {
    const maintenance = details.maintenance.get(item.orderId);
    return {
      ...item,
      services: details.services.get(item.orderId) ?? [],
      labor: details.labor.get(item.orderId) ?? [],
      parts: details.parts.get(item.orderId) ?? [],
      maintenance: maintenance ? presentMaintenance(maintenance, vehicle.currentMileage) : null,
    };
  });

  return {
    data: {
      vehicle: {
        id: vehicle.id,
        brand: vehicle.brand,
        model: vehicle.model,
        year: vehicle.year,
        licensePlate: vehicle.licensePlate,
        currentMileage: vehicle.currentMileage,
      },
      entries,
      pendingMaintenance: pending ? presentMaintenance(pending, vehicle.currentMileage) : null,
    },
    total,
  };
}
