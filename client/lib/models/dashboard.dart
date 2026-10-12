/// Indicadores y actividad reciente del panel de control (solo administración). Todo se calcula en el servidor con
/// los datos reales de los módulos; el cliente solo lo muestra.
class Dashboard {
  const Dashboard({
    required this.generatedAt,
    required this.attendedLast30Days,
    required this.inRepair,
    required this.pendingOrders,
    required this.finishedAwaitingDelivery,
    required this.upcomingAppointments,
    required this.upcomingMaintenance,
    required this.overdueMaintenance,
    required this.lowStock,
    required this.outOfStock,
    required this.ordersAwaitingPayment,
    required this.pendingMercadoPago,
    required this.orderChanges,
    required this.payments,
    required this.inventoryMovements,
    this.ordersByStatus = const [],
    this.incomeByMonth = const [],
    this.incomeByMethod = const [],
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> group(String key) => Map<String, dynamic>.from(json[key] as Map);
    int number(Map<String, dynamic> map, String key) => (map[key] as num?)?.toInt() ?? 0;
    List<T> items<T>(Map<String, dynamic> map, String key, T Function(Map<String, dynamic>) build) =>
        ((map[key] as List?) ?? const []).map((e) => build(Map<String, dynamic>.from(e as Map))).toList();
    final orders = group('orders');
    final appointments = group('appointments');
    final maintenance = group('maintenance');
    final inventory = group('inventory');
    final payments = group('payments');
    final activity = group('recentActivity');
    final charts = json['charts'] is Map ? group('charts') : <String, dynamic>{};
    return Dashboard(
      generatedAt: DateTime.parse('${json['generatedAt']}'),
      attendedLast30Days: number(orders, 'attendedLast30Days'),
      inRepair: number(orders, 'inRepair'),
      pendingOrders: number(orders, 'pending'),
      finishedAwaitingDelivery: number(orders, 'finishedAwaitingDelivery'),
      upcomingAppointments: number(appointments, 'upcoming'),
      upcomingMaintenance: number(maintenance, 'upcoming'),
      overdueMaintenance: number(maintenance, 'overdue'),
      lowStock: number(inventory, 'lowStock'),
      outOfStock: number(inventory, 'outOfStock'),
      ordersAwaitingPayment: number(payments, 'ordersAwaitingPayment'),
      pendingMercadoPago: number(payments, 'pendingMercadoPago'),
      orderChanges: items(activity, 'orderChanges', OrderChangeActivity.fromJson),
      payments: items(activity, 'payments', PaymentActivity.fromJson),
      inventoryMovements: items(activity, 'inventoryMovements', InventoryActivity.fromJson),
      ordersByStatus: items(charts, 'ordersByStatus', OrderStatusCount.fromJson),
      incomeByMonth: items(charts, 'incomeByMonth', MonthlyIncome.fromJson),
      incomeByMethod: items(charts, 'incomeByMethod', MethodIncome.fromJson),
    );
  }

  final DateTime generatedAt;
  final int attendedLast30Days;
  final int inRepair;
  final int pendingOrders;
  final int finishedAwaitingDelivery;
  final int upcomingAppointments;
  final int upcomingMaintenance;
  final int overdueMaintenance;
  final int lowStock;
  final int outOfStock;
  final int ordersAwaitingPayment;
  final int pendingMercadoPago;
  final List<OrderChangeActivity> orderChanges;
  final List<PaymentActivity> payments;
  final List<InventoryActivity> inventoryMovements;

  /// Datos de las gráficas: órdenes por estado, e ingresos pagados por mes y por método (últimos 6 meses).
  final List<OrderStatusCount> ordersByStatus;
  final List<MonthlyIncome> incomeByMonth;
  final List<MethodIncome> incomeByMethod;

  bool get hasRecentActivity => orderChanges.isNotEmpty || payments.isNotEmpty || inventoryMovements.isNotEmpty;
}

/// Cambio de estado reciente de una orden.
class OrderChangeActivity {
  const OrderChangeActivity({required this.folio, required this.toStatus, required this.changedBy, required this.changedAt});

  factory OrderChangeActivity.fromJson(Map<String, dynamic> json) => OrderChangeActivity(
        folio: '${json['folio']}',
        toStatus: '${json['toStatus']}',
        changedBy: '${json['changedBy']}',
        changedAt: DateTime.parse('${json['changedAt']}'),
      );

  final String folio;
  final String toStatus;
  final String changedBy;
  final DateTime changedAt;
}

/// Pago reciente.
class PaymentActivity {
  const PaymentActivity({required this.orderFolio, required this.amount, required this.method, required this.status, required this.createdAt});

  factory PaymentActivity.fromJson(Map<String, dynamic> json) => PaymentActivity(
        orderFolio: '${json['orderFolio']}',
        amount: '${json['amount']}',
        method: '${json['method']}',
        status: '${json['status']}',
        createdAt: DateTime.parse('${json['createdAt']}'),
      );

  final String orderFolio;
  final String amount;
  final String method;
  final String status;
  final DateTime createdAt;
}

/// Movimiento de inventario reciente.
class InventoryActivity {
  const InventoryActivity({required this.partCode, required this.type, required this.quantity, required this.createdAt});

  factory InventoryActivity.fromJson(Map<String, dynamic> json) => InventoryActivity(
        partCode: '${json['partCode']}',
        type: '${json['type']}',
        quantity: (json['quantity'] as num).toInt(),
        createdAt: DateTime.parse('${json['createdAt']}'),
      );

  final String partCode;
  final String type;
  final int quantity;
  final DateTime createdAt;
}

/// Cantidad de órdenes en un estado (gráfica de dona).
class OrderStatusCount {
  const OrderStatusCount({required this.status, required this.total});

  factory OrderStatusCount.fromJson(Map<String, dynamic> json) =>
      OrderStatusCount(status: '${json['status']}', total: (json['total'] as num?)?.toInt() ?? 0);

  final String status;
  final int total;
}

/// Ingresos pagados de un mes (`YYYY-MM`) para la gráfica de barras.
class MonthlyIncome {
  const MonthlyIncome({required this.month, required this.total});

  factory MonthlyIncome.fromJson(Map<String, dynamic> json) =>
      MonthlyIncome(month: '${json['month']}', total: (json['total'] as num?)?.toDouble() ?? 0);

  final String month;
  final double total;

  /// Número de mes de 1 a 12.
  int get monthNumber => int.tryParse(month.split('-').last) ?? 1;
}

/// Ingresos pagados con un método de pago.
class MethodIncome {
  const MethodIncome({required this.method, required this.total});

  factory MethodIncome.fromJson(Map<String, dynamic> json) =>
      MethodIncome(method: '${json['method']}', total: (json['total'] as num?)?.toDouble() ?? 0);

  final String method;
  final double total;
}
