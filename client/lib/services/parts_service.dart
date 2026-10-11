import '../models/inventory_movement.dart';
import '../models/paged_result.dart';
import '../models/part.dart';
import '../utils/status_labels.dart';
import 'api_client.dart';

/// Consumo de la API de refacciones: catálogo, movimientos de inventario y alertas de stock.
class PartsService {
  const PartsService(this._api);

  final ApiClient _api;

  PagedResult<T> _paged<T>(ApiResponse response, T Function(Map<String, dynamic>) build, int page, int pageSize) =>
      PagedResult(
        items: response.list.map(build).toList(),
        total: response.total,
        page: (response.meta?['page'] as num?)?.toInt() ?? page,
        pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
      );

  /// Catálogo. El mecánico recibe siempre solo las activas y con la vista reducida.
  Future<PagedResult<Part>> list({
    String? search,
    StockStatus? stockStatus,
    bool? active,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get('/parts', query: {
      'search': search,
      'stockStatus': stockStatus?.apiValue,
      'active': active,
      'page': page,
      'pageSize': pageSize,
    });
    return _paged(response, Part.fromJson, page, pageSize);
  }

  Future<Part> get(int id) async => Part.fromJson((await _api.get('/parts/$id')).map);

  Future<Part> create(PartInput input) async => Part.fromJson((await _api.post('/parts', body: input.toJson())).map);

  /// Edita los datos de la refacción (el código y el stock no cambian por esta vía).
  Future<Part> update(int id, PartInput input) async => Part.fromJson((await _api.patch('/parts/$id', body: {
        'name': input.name,
        'description': input.description,
        'unit': input.unit,
        'minStock': input.minStock,
      })).map);

  Future<Part> setActive(int id, bool active) async =>
      Part.fromJson((await _api.patch('/parts/$id', body: {'active': active})).map);

  Future<PagedResult<InventoryMovement>> movements(int partId, {int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/parts/$partId/movements', query: {'page': page, 'pageSize': pageSize});
    return _paged(response, InventoryMovement.fromJson, page, pageSize);
  }

  /// Entrada de mercancía.
  Future<Part> receive(int partId, int quantity, {String? reason}) async {
    final response = await _api.post('/parts/$partId/movements', body: {
      'type': 'IN',
      'quantity': quantity,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return Part.fromJson(Map<String, dynamic>.from(response.map['part'] as Map));
  }

  /// Ajuste por conteo físico: el stock queda en [countedQuantity].
  Future<Part> adjust(int partId, int countedQuantity, String reason) async {
    final response = await _api.post('/parts/$partId/movements', body: {
      'type': 'ADJUSTMENT',
      'countedQuantity': countedQuantity,
      'reason': reason,
    });
    return Part.fromJson(Map<String, dynamic>.from(response.map['part'] as Map));
  }

  /// Alertas de stock bajo (solo administración).
  Future<StockAlerts> alerts() async => StockAlerts.fromJson((await _api.get('/parts/alerts')).map);
}
