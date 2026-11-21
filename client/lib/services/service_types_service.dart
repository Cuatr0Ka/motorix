import '../models/service_type.dart';
import 'api_client.dart';

/// Consumo de la API de tipos de servicio y de la propuesta del próximo mantenimiento.
class ServiceTypesService {
  const ServiceTypesService(this._api);

  final ApiClient _api;

  /// Lista de gestión (administración): todos los tipos, también los desactivados.
  Future<List<ServiceType>> list() async => (await _api.get('/service-types')).list.map(ServiceType.fromJson).toList();

  /// Solo los activos, para elegirlos en una línea de servicio (administración y mecánico).
  Future<List<ServiceType>> options() async =>
      (await _api.get('/service-types/options')).list.map(ServiceType.fromJson).toList();

  Future<ServiceType> create(ServiceTypeInput input) async =>
      ServiceType.fromJson((await _api.post('/service-types', body: input.toJson())).map);

  Future<ServiceType> update(int id, Map<String, dynamic> changes) async =>
      ServiceType.fromJson((await _api.patch('/service-types/$id', body: changes)).map);

  /// Propuesta del próximo mantenimiento de la orden; null si ningún servicio tiene un tipo con intervalo (204).
  Future<MaintenanceSuggestion?> suggestion(int orderId) async {
    final response = await _api.get('/orders/$orderId/maintenance/suggestion');
    if (response.data == null) return null;
    return MaintenanceSuggestion.fromJson(response.map);
  }
}
