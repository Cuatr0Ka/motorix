import '../utils/status_labels.dart';

/// Tipo de aviso del centro de notificaciones. `apiValue` es el valor que viaja en la API. El color nunca es la
/// única señal: cada tipo también tiene un nombre de sección y un título.
enum NoticeType {
  maintenanceOverdue('MAINT_OVERDUE', 'Mantenimientos vencidos', StatusTone.danger),
  stockOut('STOCK_OUT', 'Stock agotado', StatusTone.danger),
  stalledOrder('STALLED', 'Órdenes detenidas', StatusTone.warning),
  appointmentToday('APPT_TODAY', 'Citas de hoy', StatusTone.neutral),
  maintenanceUpcoming('MAINT_UPCOMING', 'Mantenimientos próximos', StatusTone.warning),
  stockLow('STOCK_LOW', 'Stock bajo', StatusTone.warning);

  const NoticeType(this.apiValue, this.sectionTitle, this.tone);

  final String apiValue;

  /// Nombre de la sección del panel.
  final String sectionTitle;
  final StatusTone tone;

  /// Los avisos vencidos o de stock agotado hacen que la campana use el color de error.
  bool get isCritical => tone == StatusTone.danger;

  static NoticeType? fromApi(String? value) {
    for (final item in NoticeType.values) {
      if (item.apiValue == value) return item;
    }
    return null;
  }
}

/// Pantalla a la que lleva un aviso: orden, cita, vehículo o refacción (inventario).
class NoticeTarget {
  const NoticeTarget({required this.kind, required this.id});

  factory NoticeTarget.fromJson(Map<String, dynamic> json) =>
      NoticeTarget(kind: '${json['kind']}', id: (json['id'] as num).toInt());

  /// `order`, `appointment`, `vehicle` o `part`.
  final String kind;
  final int id;
}

/// Un aviso del usuario. Los campos opcionales dependen del tipo (`dueDate`, `scheduledAt`, `stock`...).
class AppNotice {
  const AppNotice({
    required this.key,
    required this.type,
    required this.read,
    required this.title,
    required this.detail,
    required this.target,
    this.dueDate,
    this.dueMileage,
    this.scheduledAt,
    this.stock,
    this.minStock,
    this.folio,
    this.status,
    this.daysStalled,
  });

  factory AppNotice.fromJson(Map<String, dynamic> json) => AppNotice(
        key: '${json['key']}',
        type: NoticeType.fromApi(json['type'] as String?) ?? NoticeType.maintenanceUpcoming,
        read: json['read'] == true,
        title: '${json['title']}',
        detail: '${json['detail'] ?? ''}',
        target: NoticeTarget.fromJson(Map<String, dynamic>.from(json['target'] as Map)),
        dueDate: json['dueDate'] == null ? null : DateTime.parse('${json['dueDate']}'),
        dueMileage: (json['dueMileage'] as num?)?.toInt(),
        scheduledAt: json['scheduledAt'] == null ? null : DateTime.parse('${json['scheduledAt']}').toLocal(),
        stock: (json['stock'] as num?)?.toInt(),
        minStock: (json['minStock'] as num?)?.toInt(),
        folio: json['folio'] as String?,
        status: json['status'] as String?,
        daysStalled: (json['daysStalled'] as num?)?.toInt(),
      );

  /// Clave estable del aviso (`TIPO:id` o `TIPO:id:variante`); es la que se envía para marcarlo como leído.
  final String key;
  final NoticeType type;
  final bool read;
  final String title;
  final String detail;
  final NoticeTarget target;
  final DateTime? dueDate;
  final int? dueMileage;
  final DateTime? scheduledAt;
  final int? stock;
  final int? minStock;
  final String? folio;
  final String? status;
  final int? daysStalled;

  AppNotice copyWith({bool? read}) => AppNotice(
        key: key,
        type: type,
        read: read ?? this.read,
        title: title,
        detail: detail,
        target: target,
        dueDate: dueDate,
        dueMileage: dueMileage,
        scheduledAt: scheduledAt,
        stock: stock,
        minStock: minStock,
        folio: folio,
        status: status,
        daysStalled: daysStalled,
      );
}

/// Avisos de un mismo tipo. `total` y `unread` cuentan todos los avisos, aunque `items` traiga como máximo 50.
class NoticeGroup {
  const NoticeGroup({required this.type, required this.total, required this.unread, required this.items});

  factory NoticeGroup.fromJson(Map<String, dynamic> json) => NoticeGroup(
        type: NoticeType.fromApi(json['type'] as String?) ?? NoticeType.maintenanceUpcoming,
        total: (json['total'] as num).toInt(),
        unread: (json['unread'] as num).toInt(),
        items: (json['items'] as List<dynamic>)
            .map((item) => AppNotice.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );

  final NoticeType type;
  final int total;
  final int unread;
  final List<AppNotice> items;

  /// Hay más avisos de este tipo de los que se listan.
  bool get isTruncated => total > items.length;

  NoticeGroup copyWith({int? unread, List<AppNotice>? items}) =>
      NoticeGroup(type: type, total: total, unread: unread ?? this.unread, items: items ?? this.items);
}

/// Respuesta de `GET /notifications`: total de no leídos (el de la campana) y los grupos por tipo.
class NoticesSummary {
  const NoticesSummary({required this.unread, required this.total, required this.groups, this.generatedAt});

  factory NoticesSummary.fromJson(Map<String, dynamic> json) => NoticesSummary(
        unread: (json['unread'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        groups: (json['groups'] as List<dynamic>)
            .map((group) => NoticeGroup.fromJson(Map<String, dynamic>.from(group as Map)))
            .toList(),
        generatedAt: json['generatedAt'] == null ? null : DateTime.tryParse('${json['generatedAt']}'),
      );

  static const empty = NoticesSummary(unread: 0, total: 0, groups: []);

  final int unread;
  final int total;
  final List<NoticeGroup> groups;
  final DateTime? generatedAt;

  /// Hay al menos un aviso crítico (vencido o stock agotado) sin leer.
  bool get hasCriticalUnread =>
      groups.any((group) => group.type.isCritical && group.items.any((item) => !item.read));

  NoticesSummary copyWith({int? unread, List<NoticeGroup>? groups}) => NoticesSummary(
        unread: unread ?? this.unread,
        total: total,
        groups: groups ?? this.groups,
        generatedAt: generatedAt,
      );
}
