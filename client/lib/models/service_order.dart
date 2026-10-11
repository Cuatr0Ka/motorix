import '../utils/status_labels.dart';
import 'maintenance.dart';
import 'order_work.dart';

class OrderClient {
  const OrderClient({required this.id, required this.name});

  factory OrderClient.fromJson(Map<String, dynamic> json) =>
      OrderClient(id: (json['id'] as num).toInt(), name: '${json['name']}');

  final int id;
  final String name;
}

class OrderVehicle {
  const OrderVehicle({required this.id, required this.brand, required this.model, required this.licensePlate});

  factory OrderVehicle.fromJson(Map<String, dynamic> json) => OrderVehicle(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        licensePlate: '${json['licensePlate']}',
      );

  final int id;
  final String brand;
  final String model;
  final String licensePlate;

  String get label => '$licensePlate · $brand $model';
}

class OrderMechanic {
  const OrderMechanic({required this.id, required this.name});

  factory OrderMechanic.fromJson(Map<String, dynamic> json) =>
      OrderMechanic(id: (json['id'] as num).toInt(), name: '${json['name']}');

  final int id;
  final String name;
}

/// Cita de origen de una orden (datos mínimos).
class OrderAppointmentRef {
  const OrderAppointmentRef({required this.id, required this.status});

  factory OrderAppointmentRef.fromJson(Map<String, dynamic> json) => OrderAppointmentRef(
        id: (json['id'] as num).toInt(),
        status: AppointmentStatus.fromApi(json['status'] as String?),
      );

  final int id;
  final AppointmentStatus status;
}

/// Un cambio de estado del historial de la orden.
class StatusChange {
  const StatusChange({required this.fromStatus, required this.toStatus, required this.changedBy, required this.changedAt});

  factory StatusChange.fromJson(Map<String, dynamic> json) => StatusChange(
        fromStatus: json['fromStatus'] == null ? null : OrderStatus.fromApi(json['fromStatus'] as String?),
        toStatus: OrderStatus.fromApi(json['toStatus'] as String?),
        changedBy: '${(json['changedBy'] as Map)['name']}',
        changedAt: DateTime.parse('${json['changedAt']}'),
      );

  final OrderStatus? fromStatus;
  final OrderStatus toStatus;
  final String changedBy;
  final DateTime changedAt;
}

/// Orden de servicio. En los listados solo trae el resumen; el detalle añade el trabajo, los totales,
/// el historial y las transiciones que puede ejecutar quien consulta.
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.folio,
    required this.status,
    required this.reportedProblem,
    required this.entryMileage,
    required this.createdAt,
    required this.client,
    required this.vehicle,
    this.mechanic,
    this.diagnosis,
    this.observations,
    this.recommendations,
    this.mileageCorrection = false,
    this.mileageCorrectionReason,
    this.appointment,
    this.services = const [],
    this.labor = const [],
    this.parts = const [],
    this.serviceMileage,
    this.maintenance,
    this.totals = OrderTotals.zero,
    this.allowedTransitions = const [],
    this.statusHistory = const [],
    this.deliveredAt,
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> json) => ServiceOrder(
        id: (json['id'] as num).toInt(),
        folio: '${json['folio']}',
        status: OrderStatus.fromApi(json['status'] as String?),
        reportedProblem: '${json['reportedProblem']}',
        entryMileage: (json['entryMileage'] as num).toInt(),
        createdAt: DateTime.parse('${json['createdAt']}'),
        client: OrderClient.fromJson(Map<String, dynamic>.from(json['client'] as Map)),
        vehicle: OrderVehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map)),
        mechanic: json['mechanic'] == null ? null : OrderMechanic.fromJson(Map<String, dynamic>.from(json['mechanic'] as Map)),
        diagnosis: json['diagnosis'] as String?,
        observations: json['observations'] as String?,
        recommendations: json['recommendations'] as String?,
        mileageCorrection: json['mileageCorrection'] as bool? ?? false,
        mileageCorrectionReason: json['mileageCorrectionReason'] as String?,
        appointment: json['appointment'] == null
            ? null
            : OrderAppointmentRef.fromJson(Map<String, dynamic>.from(json['appointment'] as Map)),
        services: (json['services'] as List? ?? const [])
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        labor: (json['labor'] as List? ?? const [])
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        parts: (json['parts'] as List? ?? const [])
            .map((e) => OrderPart.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        serviceMileage: (json['serviceMileage'] as num?)?.toInt(),
        maintenance: json['maintenance'] == null
            ? null
            : Maintenance.fromJson(Map<String, dynamic>.from(json['maintenance'] as Map)),
        totals: json['totals'] == null ? OrderTotals.zero : OrderTotals.fromJson(Map<String, dynamic>.from(json['totals'] as Map)),
        allowedTransitions: (json['allowedTransitions'] as List? ?? const [])
            .map((e) => OrderStatus.fromApi('$e'))
            .toList(),
        statusHistory: (json['statusHistory'] as List? ?? const [])
            .map((e) => StatusChange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        deliveredAt: json['deliveredAt'] == null ? null : DateTime.parse('${json['deliveredAt']}'),
      );

  final int id;
  final String folio;
  final OrderStatus status;
  final String reportedProblem;
  final int entryMileage;
  final DateTime createdAt;
  final OrderClient client;
  final OrderVehicle vehicle;
  final OrderMechanic? mechanic;
  final String? diagnosis;
  final String? observations;
  final String? recommendations;
  final bool mileageCorrection;
  final String? mileageCorrectionReason;
  final OrderAppointmentRef? appointment;
  final List<OrderLine> services;
  final List<OrderLine> labor;
  final List<OrderPart> parts;

  /// Kilometraje al terminar el servicio (se registra con la orden Terminada).
  final int? serviceMileage;

  /// Último mantenimiento programado desde esta orden, si existe.
  final Maintenance? maintenance;
  final OrderTotals totals;
  final List<OrderStatus> allowedTransitions;
  final List<StatusChange> statusHistory;
  final DateTime? deliveredAt;

  bool get isDelivered => status == OrderStatus.delivered;

  /// Servicio concluido (Terminada o Entregada): permite programar el próximo mantenimiento.
  bool get isFinishedOrDelivered => status == OrderStatus.finished || status == OrderStatus.delivered;

  /// Aún se puede asignar o reasignar mecánico (no está terminada ni entregada).
  bool get isAssignable => status != OrderStatus.finished && status != OrderStatus.delivered;
}

/// Datos capturados en el formulario de orden: directa (por vehículo) o desde una cita.
class OrderInput {
  const OrderInput({
    this.vehicleId,
    this.appointmentId,
    required this.entryMileage,
    this.reportedProblem,
    this.mechanicId,
    this.mileageCorrection = false,
    this.mileageCorrectionReason,
  });

  final int? vehicleId;
  final int? appointmentId;
  final int entryMileage;
  final String? reportedProblem;
  final int? mechanicId;
  final bool mileageCorrection;
  final String? mileageCorrectionReason;

  Map<String, dynamic> toJson() => {
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        'entryMileage': entryMileage,
        if (reportedProblem != null && reportedProblem!.isNotEmpty) 'reportedProblem': reportedProblem,
        if (mechanicId != null) 'mechanicId': mechanicId,
        if (mileageCorrection) 'mileageCorrection': true,
        if (mileageCorrection && mileageCorrectionReason != null) 'mileageCorrectionReason': mileageCorrectionReason,
      };
}
