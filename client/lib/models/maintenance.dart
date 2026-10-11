import '../utils/status_labels.dart';

/// Mantenimiento programado para un vehículo. En el historial solo llegan los datos básicos; en la
/// lista general también el vehículo y el cliente (el mecánico no recibe `client`).
class Maintenance {
  const Maintenance({
    required this.id,
    required this.description,
    required this.status,
    this.dueDate,
    this.dueMileage,
    this.indicator,
    this.orderId,
    this.orderFolio,
    this.vehicle,
    this.client,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) => Maintenance(
        id: (json['id'] as num).toInt(),
        description: '${json['description']}',
        status: '${json['status']}',
        dueDate: json['dueDate'] == null ? null : DateTime.parse('${json['dueDate']}'),
        dueMileage: (json['dueMileage'] as num?)?.toInt(),
        indicator: MaintenanceIndicator.fromApi(json['indicator'] as String?),
        orderId: (json['orderId'] as num?)?.toInt(),
        orderFolio: json['orderFolio'] as String?,
        vehicle: json['vehicle'] == null
            ? null
            : MaintenanceVehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map)),
        client: json['client'] == null
            ? null
            : MaintenanceClient.fromJson(Map<String, dynamic>.from(json['client'] as Map)),
      );

  final int id;
  final String description;

  /// `PENDIENTE` o `ATENDIDO`.
  final String status;
  final DateTime? dueDate;
  final int? dueMileage;

  /// Solo existe mientras está pendiente.
  final MaintenanceIndicator? indicator;
  final int? orderId;
  final String? orderFolio;
  final MaintenanceVehicle? vehicle;
  final MaintenanceClient? client;

  bool get isAttended => status == 'ATENDIDO';
}

class MaintenanceVehicle {
  const MaintenanceVehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.licensePlate,
    this.currentMileage,
  });

  factory MaintenanceVehicle.fromJson(Map<String, dynamic> json) => MaintenanceVehicle(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        licensePlate: '${json['licensePlate']}',
        currentMileage: (json['currentMileage'] as num?)?.toInt(),
      );

  final int id;
  final String brand;
  final String model;
  final String licensePlate;
  final int? currentMileage;
}

class MaintenanceClient {
  const MaintenanceClient({required this.id, required this.name, this.phone});

  factory MaintenanceClient.fromJson(Map<String, dynamic> json) => MaintenanceClient(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        phone: json['phone'] as String?,
      );

  final int id;
  final String name;
  final String? phone;
}

/// Datos para programar o editar un mantenimiento. Al menos uno de los dos objetivos es obligatorio.
class MaintenanceInput {
  const MaintenanceInput({required this.description, this.dueDate, this.dueMileage});

  final String description;
  final DateTime? dueDate;
  final int? dueMileage;

  Map<String, dynamic> toJson() => {
        'description': description,
        'dueDate': dueDate == null ? null : _dateOnly(dueDate!),
        'dueMileage': dueMileage,
      };
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
