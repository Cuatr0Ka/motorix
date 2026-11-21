import '../models/notice.dart';
import 'api_client.dart';

/// Consumo de la API de notificaciones internas. Los avisos se calculan en el servidor según el rol vigente.
class NotificationsService {
  const NotificationsService(this._api);

  final ApiClient _api;

  /// Avisos del usuario: total de no leídos y grupos por tipo.
  Future<NoticesSummary> fetch() async => NoticesSummary.fromJson((await _api.get('/notifications')).map);
}
