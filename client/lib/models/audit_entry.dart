/// Acciones sensibles que registra la bitácora, con su nombre en español.
const Map<String, String> kAuditActionLabels = {
  'LOGIN_FAILED': 'Inicio de sesión fallido',
  'ACCOUNT_LOCKED': 'Cuenta bloqueada',
  'PASSWORD_CHANGED': 'Cambio de contraseña',
  'USER_CREATED': 'Usuario creado',
  'USER_DEACTIVATED': 'Usuario desactivado',
  'USER_ACTIVATED': 'Usuario activado',
  'USER_ROLE_CHANGED': 'Cambio de rol',
  'SETTINGS_CHANGED': 'Configuración modificada',
  'SERVICE_TYPE_CHANGED': 'Tipo de servicio modificado',
  'PART_PRICE_CHANGED': 'Cambio de precio',
  'PAYMENT_CANCELLED': 'Pago cancelado',
  'TERMS_ACCEPTED': 'Términos aceptados',
};

String auditActionLabel(String action) => kAuditActionLabels[action] ?? action;

/// Fila de la bitácora: quién, cuándo, qué y sobre qué.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.summary,
    this.actorName,
    this.actorUsername,
    this.entityType,
    this.entityId,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    return AuditEntry(
      id: (json['id'] as num).toInt(),
      createdAt: DateTime.parse('${json['createdAt']}').toLocal(),
      action: '${json['action']}',
      summary: '${json['summary']}',
      actorName: actor is Map ? '${actor['name']}' : null,
      actorUsername: actor is Map ? '${actor['username']}' : null,
      entityType: json['entityType'] as String?,
      entityId: (json['entityId'] as num?)?.toInt(),
    );
  }

  final int id;
  final DateTime createdAt;
  final String action;
  final String summary;
  final String? actorName;
  final String? actorUsername;
  final String? entityType;
  final int? entityId;

  String get entityLabel => entityType == null ? '—' : (entityId == null ? entityType! : '${entityType!} #$entityId');
}

/// Una página de la bitácora.
class AuditPage {
  const AuditPage({required this.items, required this.total, required this.page, required this.pageSize});

  final List<AuditEntry> items;
  final int total;
  final int page;
  final int pageSize;

  int get pages => total == 0 ? 1 : (total / pageSize).ceil();
}
