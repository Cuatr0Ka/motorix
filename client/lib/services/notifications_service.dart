import '../models/notice.dart';
import 'api_client.dart';

/// Consumo de la API de notificaciones internas. Los avisos se calculan en el servidor según el rol vigente.
class NotificationsService {
  const NotificationsService(this._api);

  final ApiClient _api;

  /// Avisos del usuario: total de no leídos y grupos por tipo.
  Future<NoticesSummary> fetch() async => NoticesSummary.fromJson((await _api.get('/notifications')).map);

  /// Marca avisos como leídos para el usuario. Devuelve cuántos eran vigentes y el total de no leídos que quedó.
  Future<({int marked, int unread})> markRead(List<String> keys) async {
    final data = (await _api.post('/notifications/read', body: {'keys': keys})).map;
    return (marked: (data['marked'] as num).toInt(), unread: (data['unread'] as num).toInt());
  }
}
