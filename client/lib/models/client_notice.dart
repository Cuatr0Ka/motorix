import '../utils/status_labels.dart';

/// Motivo por el que se debe avisar a un cliente. `apiValue` es el valor que viaja en la API.
enum ClientNoticeReason {
  orderReady('ORDER_READY', 'Vehículo listo', StatusTone.success),
  appointmentTomorrow('APPT_TOMORROW', 'Cita de mañana', StatusTone.warning),
  maintenanceUpcoming('MAINT_UPCOMING', 'Mantenimiento próximo', StatusTone.warning),
  maintenanceOverdue('MAINT_OVERDUE', 'Mantenimiento vencido', StatusTone.danger);

  const ClientNoticeReason(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static ClientNoticeReason? fromApi(String? value) {
    for (final item in ClientNoticeReason.values) {
      if (item.apiValue == value) return item;
    }
    return null;
  }
}

/// Cliente de un aviso pendiente. El teléfono puede venir vacío (dato antiguo).
class NoticeClient {
  const NoticeClient({required this.id, required this.name, required this.phone});

  factory NoticeClient.fromJson(Map<String, dynamic> json) => NoticeClient(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        phone: '${json['phone'] ?? ''}',
      );

  final int id;
  final String name;
  final String phone;

  bool get hasPhone => phone.trim().isNotEmpty;
}

/// Vehículo de un aviso pendiente.
class NoticeVehicle {
  const NoticeVehicle({required this.id, required this.brand, required this.model, required this.licensePlate});

  factory NoticeVehicle.fromJson(Map<String, dynamic> json) => NoticeVehicle(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        licensePlate: '${json['licensePlate']}',
      );

  final int id;
  final String brand;
  final String model;
  final String licensePlate;

  /// Ejemplo: «Nissan Versa · ABC-123».
  String get label => '$brand $model · $licensePlate';
}

/// Cliente por avisar: un hecho (orden, cita o mantenimiento) que la recepción todavía no ha avisado.
class PendingClientNotice {
  const PendingClientNotice({
    required this.reason,
    required this.factId,
    required this.client,
    required this.vehicle,
    this.factDate,
    this.folio,
    this.description,
  });

  factory PendingClientNotice.fromJson(Map<String, dynamic> json) => PendingClientNotice(
        reason: ClientNoticeReason.fromApi(json['reason'] as String?) ?? ClientNoticeReason.orderReady,
        factId: (json['factId'] as num).toInt(),
        factDate: json['factDate'] == null ? null : DateTime.tryParse('${json['factDate']}'),
        folio: json['folio'] as String?,
        description: json['description'] as String?,
        client: NoticeClient.fromJson(Map<String, dynamic>.from(json['client'] as Map)),
        vehicle: NoticeVehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map)),
      );

  final ClientNoticeReason reason;
  final int factId;
  final DateTime? factDate;

  /// Solo en `ORDER_READY`.
  final String? folio;
  final String? description;
  final NoticeClient client;
  final NoticeVehicle vehicle;

  /// Identifica la fila (motivo y hecho) para quitarla de la lista al marcarla como avisada.
  String get rowKey => '${reason.apiValue}:$factId';
}
