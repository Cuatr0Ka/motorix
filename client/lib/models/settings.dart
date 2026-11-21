/// De dónde sale un valor de la configuración: guardado en la aplicación, variable de entorno de respaldo o predeterminado.
enum SettingSource {
  stored('STORED', 'Guardado'),
  env('ENV', 'Variable de entorno'),
  defaults('DEFAULT', 'Predeterminado');

  const SettingSource(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SettingSource fromApi(String? value) {
    for (final item in SettingSource.values) {
      if (item.apiValue == value) return item;
    }
    return SettingSource.defaults;
  }
}

/// Datos del taller que se imprimen en el ticket.
class ShopSettings {
  const ShopSettings({required this.name, required this.address, required this.phone});

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
        name: '${json['name'] ?? ''}',
        address: '${json['address'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
      );

  final String name;
  final String address;
  final String phone;
}

/// Márgenes con los que un mantenimiento se considera «Próximo».
class MaintenanceSettings {
  const MaintenanceSettings({required this.warnDays, required this.warnKm});

  factory MaintenanceSettings.fromJson(Map<String, dynamic> json) => MaintenanceSettings(
        warnDays: (json['warnDays'] as num).toInt(),
        warnKm: (json['warnKm'] as num).toInt(),
      );

  final int warnDays;
  final int warnKm;
}

/// Configuración completa con el origen de cada valor (`sources`, por clave como `shop.name`).
class SettingsSnapshot {
  const SettingsSnapshot({required this.shop, required this.maintenance, required this.sources});

  factory SettingsSnapshot.fromJson(Map<String, dynamic> json) => SettingsSnapshot(
        shop: ShopSettings.fromJson(Map<String, dynamic>.from(json['shop'] as Map)),
        maintenance: MaintenanceSettings.fromJson(Map<String, dynamic>.from(json['maintenance'] as Map)),
        sources: {
          for (final entry in Map<String, dynamic>.from(json['sources'] as Map).entries)
            entry.key: SettingSource.fromApi('${entry.value}'),
        },
      );

  final ShopSettings shop;
  final MaintenanceSettings maintenance;
  final Map<String, SettingSource> sources;

  SettingSource sourceOf(String key) => sources[key] ?? SettingSource.defaults;
}
