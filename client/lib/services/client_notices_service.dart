import '../models/client_notice.dart';
import 'api_client.dart';

/// Consumo de la API de clientes por avisar (solo administración y recepción). El sistema únicamente registra
/// que la recepción avisó: no envía ningún mensaje al cliente.
class ClientNoticesService {
  const ClientNoticesService(this._api);

  final ApiClient _api;

  /// Clientes por avisar, con el total real aunque la lista se limite.
  Future<({List<PendingClientNotice> items, int total})> list() async {
    final response = await _api.get('/client-notices');
    return (items: response.list.map(PendingClientNotice.fromJson).toList(), total: response.total);
  }

  /// Registra el aviso. El servidor responde 201 si lo creó y 200 si ya estaba avisado; las dos son éxito.
  Future<void> markNotified(ClientNoticeReason reason, int factId) async {
    await _api.post('/client-notices', body: {'reason': reason.apiValue, 'factId': factId});
  }
}
