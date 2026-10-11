import '../models/paged_result.dart';
import '../models/ticket.dart';
import 'api_client.dart';

/// Consumo de la API de tickets (solo administración y recepción).
class TicketsService {
  const TicketsService(this._api);

  final ApiClient _api;

  /// Genera el ticket de la orden. Si ya tenía uno, la API devuelve el existente.
  Future<Ticket> generate(int orderId) async {
    final data = (await _api.post('/orders/$orderId/ticket')).map;
    return Ticket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map));
  }

  Future<Ticket> get(int id) async => Ticket.fromJson((await _api.get('/tickets/$id')).map);

  Future<PagedResult<Ticket>> list({String? search, int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/tickets', query: {'search': search, 'page': page, 'pageSize': pageSize});
    return PagedResult(
      items: response.list.map(Ticket.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }
}
