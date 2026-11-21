/// Tipo de servicio del catálogo (Sprint 7): nombre e intervalos opcionales para proponer el próximo mantenimiento.
class ServiceType {
  const ServiceType({
    required this.id,
    required this.name,
    this.intervalDays,
    this.intervalKm,
    this.active = true,
    this.inUse = 0,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        intervalDays: (json['intervalDays'] as num?)?.toInt(),
        intervalKm: (json['intervalKm'] as num?)?.toInt(),
        active: json['active'] as bool? ?? true,
        inUse: (json['inUse'] as num?)?.toInt() ?? 0,
      );

  final int id;
  final String name;
  final int? intervalDays;
  final int? intervalKm;
  final bool active;

  /// Número de líneas de servicio que usan el tipo (solo en la lista de gestión).
  final int inUse;
}

/// Datos del formulario de un tipo de servicio. Los intervalos nulos se envían como `null` (para quitarlos al editar).
class ServiceTypeInput {
  const ServiceTypeInput({required this.name, this.intervalDays, this.intervalKm});

  final String name;
  final int? intervalDays;
  final int? intervalKm;

  Map<String, dynamic> toJson() => {'name': name, 'intervalDays': intervalDays, 'intervalKm': intervalKm};
}

/// Próximo mantenimiento propuesto a partir de los tipos de servicio de la orden (la persona lo corrige).
class MaintenanceSuggestion {
  const MaintenanceSuggestion({this.dueDate, this.dueMileage, this.basedOn = const []});

  factory MaintenanceSuggestion.fromJson(Map<String, dynamic> json) => MaintenanceSuggestion(
        dueDate: json['dueDate'] == null ? null : DateTime.tryParse('${json['dueDate']}'),
        dueMileage: (json['dueMileage'] as num?)?.toInt(),
        basedOn: [
          for (final item in (json['basedOn'] as List? ?? const [])) '${(item as Map)['name']}',
        ],
      );

  final DateTime? dueDate;
  final int? dueMileage;

  /// Nombres de los tipos de servicio en que se basa la propuesta.
  final List<String> basedOn;
}
