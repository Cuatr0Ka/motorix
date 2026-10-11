import '../models/maintenance.dart';
import '../models/paged_result.dart';
import '../utils/status_labels.dart';
import 'api_client.dart';

/// Consumo de la API de mantenimientos. Programar se hace desde una orden; la lista general es solo
/// para recepción y administración.
class MaintenanceService {
  const MaintenanceService(this._api);

  final ApiClient _api;

  Future<PagedResult<Maintenance>> list({
    String? search,
    MaintenanceIndicator? indicator,
    String status = 'PENDIENTE',
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get('/maintenance', query: {
      'search': search,
      'indicator': indicator?.apiValue,
      'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(Maintenance.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  /// Programa el próximo mantenimiento desde una orden Terminada o Entregada.
  Future<Maintenance> schedule(int orderId, MaintenanceInput input) async =>
      Maintenance.fromJson((await _api.post('/orders/$orderId/maintenance', body: input.toJson())).map);

  Future<Maintenance> update(int id, MaintenanceInput input) async =>
      Maintenance.fromJson((await _api.patch('/maintenance/$id', body: input.toJson())).map);

  /// Marca el mantenimiento como Atendido (acción definitiva).
  Future<Maintenance> attend(int id) async => Maintenance.fromJson((await _api.post('/maintenance/$id/attend')).map);
}
