import '../models/audit_entry.dart';
import 'api_client.dart';

/// Consumo de la bitácora (solo administración, solo lectura).
class AuditService {
  const AuditService(this._api);

  final ApiClient _api;

  Future<AuditPage> list({String? from, String? to, int? userId, String? action, int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/audit-log', query: {
      'from': from,
      'to': to,
      'userId': userId,
      'action': action,
      'page': page,
      'pageSize': pageSize,
    });
    final meta = response.meta ?? const {};
    return AuditPage(
      items: response.list.map(AuditEntry.fromJson).toList(),
      total: (meta['total'] as num?)?.toInt() ?? 0,
      page: (meta['page'] as num?)?.toInt() ?? page,
      pageSize: (meta['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  /// Personas para el filtro por usuario (id y nombre).
  Future<List<({int id, String name})>> users() async {
    final response = await _api.get('/users', query: {'pageSize': 100});
    return [for (final item in response.list) (id: (item['id'] as num).toInt(), name: '${item['name']}')];
  }
}
