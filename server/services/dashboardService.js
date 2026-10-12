import * as dashboardModel from '../models/dashboardModel.js';
import * as maintenanceService from './maintenanceService.js';
import * as partService from './partService.js';

const ATTENDED_DAYS = 30;
const APPOINTMENT_DAYS = 7;
const RECENT_LIMIT = 5;
const CHART_MONTHS = 6;

const ORDER_STATUSES = ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO', 'ENTREGADO'];
const PAYMENT_METHODS = ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO'];

/** Últimos `count` meses (`YYYY-MM`), del más antiguo al actual, incluso los que no tienen movimiento. */
function lastMonths(count, now = new Date()) {
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - (count - 1 - i), 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
}

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
    ordersByStatus,
    incomeByMonth,
    incomeByMethod,
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
    dashboardModel.ordersGroupedByStatus(),
    dashboardModel.paidIncomeByMonth(CHART_MONTHS),
    dashboardModel.paidIncomeByMethod(CHART_MONTHS),
  ]);

  const statusTotals = new Map(ordersByStatus.map((row) => [row.status, row.total]));
  const monthTotals = new Map(incomeByMonth.map((row) => [row.month, row.total]));
  const methodTotals = new Map(incomeByMethod.map((row) => [row.method, row.total]));

  return {
    generatedAt: new Date().toISOString(),
    orders: { attendedLast30Days, inRepair, pending, finishedAwaitingDelivery },
    appointments: { upcoming: upcomingAppointments },
    maintenance: { upcoming: upcomingMaintenance, overdue: overdueMaintenance },
    inventory: { lowStock: alerts.count, outOfStock: alerts.outOfStock },
    payments: { ordersAwaitingPayment, pendingMercadoPago },
    recentActivity: { orderChanges, payments, inventoryMovements },
    charts: {
      ordersByStatus: ORDER_STATUSES.map((status) => ({ status, total: statusTotals.get(status) ?? 0 })),
      incomeByMonth: lastMonths(CHART_MONTHS).map((month) => ({ month, total: monthTotals.get(month) ?? 0 })),
      incomeByMethod: PAYMENT_METHODS.map((method) => ({ method, total: methodTotals.get(method) ?? 0 })),
    },
  };
}
