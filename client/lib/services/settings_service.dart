import '../models/settings.dart';
import 'api_client.dart';

/// Consumo de la API de configuración (solo administración).
class SettingsService {
  const SettingsService(this._api);

  final ApiClient _api;

  Future<SettingsSnapshot> fetch() async => SettingsSnapshot.fromJson((await _api.get('/settings')).map);

  /// Guarda solo los campos enviados: `{ 'shop': { 'name': ... }, 'maintenance': { 'warnDays': ... } }`.
  Future<SettingsSnapshot> save(Map<String, dynamic> changes) async =>
      SettingsSnapshot.fromJson((await _api.put('/settings', body: changes)).map);
}
