import '../models/terms.dart';
import 'api_client.dart';

/// Consumo de la API de términos y condiciones.
class TermsService {
  const TermsService(this._api);

  final ApiClient _api;

  Future<TermsDocument> current() async => TermsDocument.fromJson((await _api.get('/terms/current')).map);

  /// Acepta la versión indicada (debe ser la vigente).
  Future<void> accept(int versionId) async {
    await _api.post('/terms/accept', body: {'versionId': versionId});
  }

  /// Quién aceptó la versión vigente (solo administración).
  Future<TermsAcceptancesPage> acceptances({int page = 1, int pageSize = 10}) async {
    final response = await _api.get('/terms/acceptances', query: {'page': page, 'pageSize': pageSize});
    final meta = response.meta ?? const {};
    return TermsAcceptancesPage(
      items: response.list.map(TermsAcceptance.fromJson).toList(),
      total: (meta['total'] as num?)?.toInt() ?? 0,
      pending: (meta['pending'] as num?)?.toInt() ?? 0,
      page: (meta['page'] as num?)?.toInt() ?? page,
      pageSize: (meta['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }
}
