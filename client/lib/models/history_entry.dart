import 'maintenance.dart';

/// Línea de servicio o de mano de obra tal como aparece en el historial (sin identificador).
class HistoryLine {
  const HistoryLine({required this.description, required this.amount});

  factory HistoryLine.fromJson(Map<String, dynamic> json) =>
      HistoryLine(description: '${json['description']}', amount: '${json['amount']}');

  final String description;
  final String amount;
}

/// Refacción usada en un servicio del historial.
class HistoryPart {
  const HistoryPart({
    required this.partId,
    required this.code,
    required this.name,
    required this.unit,
    required this.quantity,
  });

  factory HistoryPart.fromJson(Map<String, dynamic> json) => HistoryPart(
        partId: (json['partId'] as num).toInt(),
        code: '${json['code']}',
        name: '${json['name']}',
        unit: '${json['unit']}',
        quantity: (json['quantity'] as num).toInt(),
      );

  final int partId;
  final String code;
  final String name;
  final String unit;
  final int quantity;
}

/// Servicio terminado de un vehículo (una orden Terminada o Entregada).
class HistoryEntry {
  const HistoryEntry({
    required this.orderId,
    required this.folio,
    required this.status,
    required this.serviceDate,
    required this.reportedProblem,
    required this.services,
    required this.labor,
    required this.parts,
    this.mileage,
    this.diagnosis,
    this.mechanicName,
    this.maintenance,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    List<T> items<T>(String key, T Function(Map<String, dynamic>) build) =>
        ((json[key] as List?) ?? const []).map((e) => build(Map<String, dynamic>.from(e as Map))).toList();
    return HistoryEntry(
      orderId: (json['orderId'] as num).toInt(),
      folio: '${json['folio']}',
      status: '${json['status']}',
      serviceDate: DateTime.parse('${json['serviceDate']}'),
      mileage: (json['mileage'] as num?)?.toInt(),
      reportedProblem: '${json['reportedProblem']}',
      diagnosis: json['diagnosis'] as String?,
      services: items('services', HistoryLine.fromJson),
      labor: items('labor', HistoryLine.fromJson),
      parts: items('parts', HistoryPart.fromJson),
      mechanicName: json['mechanic'] == null ? null : '${(json['mechanic'] as Map)['name']}',
      maintenance: json['maintenance'] == null
          ? null
          : Maintenance.fromJson(Map<String, dynamic>.from(json['maintenance'] as Map)),
    );
  }

  final int orderId;
  final String folio;
  final String status;
  final DateTime serviceDate;
  final int? mileage;
  final String reportedProblem;
  final String? diagnosis;
  final List<HistoryLine> services;
  final List<HistoryLine> labor;
  final List<HistoryPart> parts;
  final String? mechanicName;
  final Maintenance? maintenance;
}

/// Respuesta del historial: entradas de la página y mantenimiento vigente del vehículo.
class VehicleHistory {
  const VehicleHistory({required this.entries, required this.total, this.pendingMaintenance});

  final List<HistoryEntry> entries;
  final int total;
  final Maintenance? pendingMaintenance;
}
