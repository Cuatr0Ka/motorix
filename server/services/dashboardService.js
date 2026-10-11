import * as dashboardModel from '../models/dashboardModel.js';
import * as maintenanceService from './maintenanceService.js';
import * as partService from './partService.js';

const ATTENDED_DAYS = 30;
const APPOINTMENT_DAYS = 7;
const RECENT_LIMIT = 5;

/**
 * Panel de control del taller (solo administración). Compone, en paralelo, consultas de los módulos existentes con el
 * mismo criterio que sus listados: los mantenimientos usan la misma lista (e indicador calculado) que la pantalla de
 * Mantenimientos y las alertas de inventario usan las mismas alertas de stock. No guarda ni duplica datos.
 */
export async function getDashboard(actor) {
  const maintenanceTotal = async (indicator) =>
    (await maintenanceService.list({ status: 'PENDIENTE', indicator, page: 1, pageSize: 1 }, actor)).total;

  const [
    attendedLast30Days,
    inRepair,
    pending,
    finishedAwaitingDelivery,
    upcomingAppointments,
    upcomingMaintenance,
    overdueMaintenance,
    alerts,
    ordersAwaitingPayment,
    pendingMercadoPago,
    orderChanges,
    payments,
    inventoryMovements,
  ] = await Promise.all([
    dashboardModel.countAttendedVehicles(ATTENDED_DAYS),
    dashboardModel.countOrdersByStatuses(['EN_REPARACION', 'ESPERANDO_REFACCION']),
    dashboardModel.countOrdersByStatuses(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION']),
    dashboardModel.countOrdersByStatuses(['TERMINADO']),
    dashboardModel.countUpcomingAppointments(APPOINTMENT_DAYS),
    maintenanceTotal('PROXIMO'),
    maintenanceTotal('VENCIDO'),
    partService.alerts(),
    dashboardModel.countFinishedWithoutPayment(),
    dashboardModel.countPaymentsByStatus('PENDIENTE'),
    dashboardModel.recentOrderChanges(RECENT_LIMIT),
    dashboardModel.recentPayments(RECENT_LIMIT),
    dashboardModel.recentInventoryMovements(RECENT_LIMIT),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    orders: { attendedLast30Days, inRepair, pending, finishedAwaitingDelivery },
    appointments: { upcoming: upcomingAppointments },
    maintenance: { upcoming: upcomingMaintenance, overdue: overdueMaintenance },
    inventory: { lowStock: alerts.count, outOfStock: alerts.outOfStock },
    payments: { ordersAwaitingPayment, pendingMercadoPago },
    recentActivity: { orderChanges, payments, inventoryMovements },
  };
}
