import '../utils/status_labels.dart';

/// Resumen del cliente dentro de una cita.
class AppointmentClient {
  const AppointmentClient({required this.id, required this.name, this.phone});

  factory AppointmentClient.fromJson(Map<String, dynamic> json) => AppointmentClient(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        phone: json['phone'] as String?,
      );

  final int id;
  final String name;
  final String? phone;
}

/// Resumen del vehículo dentro de una cita.
class AppointmentVehicle {
  const AppointmentVehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
  });

  factory AppointmentVehicle.fromJson(Map<String, dynamic> json) => AppointmentVehicle(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        year: (json['year'] as num?)?.toInt() ?? 0,
        licensePlate: '${json['licensePlate']}',
      );

  final int id;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;

  String get label => '$licensePlate · $brand $model';
}

/// Orden de servicio que originó una cita (datos mínimos).
class AppointmentOrder {
  const AppointmentOrder({required this.id, required this.folio, required this.status});

  factory AppointmentOrder.fromJson(Map<String, dynamic> json) => AppointmentOrder(
        id: (json['id'] as num).toInt(),
        folio: '${json['folio']}',
        status: OrderStatus.fromApi(json['status'] as String?),
      );

  final int id;
  final String folio;
  final OrderStatus status;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.scheduledAt,
    required this.reason,
    required this.client,
    required this.vehicle,
    this.notes,
    this.cancelReason,
    this.order,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: (json['id'] as num).toInt(),
        status: AppointmentStatus.fromApi(json['status'] as String?),
        scheduledAt: DateTime.parse('${json['scheduledAt']}'),
        reason: '${json['reason']}',
        notes: json['notes'] as String?,
        cancelReason: json['cancelReason'] as String?,
        client: AppointmentClient.fromJson(Map<String, dynamic>.from(json['client'] as Map)),
        vehicle: AppointmentVehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map)),
        order: json['order'] == null ? null : AppointmentOrder.fromJson(Map<String, dynamic>.from(json['order'] as Map)),
      );

  final int id;
  final AppointmentStatus status;
  final DateTime scheduledAt;
  final String reason;
  final String? notes;
  final String? cancelReason;
  final AppointmentClient client;
  final AppointmentVehicle vehicle;
  final AppointmentOrder? order;
}

/// Datos capturados en el formulario de cita. En una edición solo viajan fecha, motivo y observaciones.
class AppointmentInput {
  const AppointmentInput({
    required this.clientId,
    required this.vehicleId,
    required this.scheduledAt,
    required this.reason,
    this.notes,
  });

  final int clientId;
  final int vehicleId;
  final DateTime scheduledAt;
  final String reason;
  final String? notes;

  Map<String, dynamic> toCreateJson() => {
        'clientId': clientId,
        'vehicleId': vehicleId,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'reason': reason,
        'notes': notes,
      };

  Map<String, dynamic> toUpdateJson() => {
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'reason': reason,
        'notes': notes,
      };
}
