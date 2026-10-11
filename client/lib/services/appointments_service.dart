import '../models/appointment.dart';
import '../models/paged_result.dart';
import '../utils/status_labels.dart';
import 'api_client.dart';

class AppointmentsService {
  const AppointmentsService(this._api);

  final ApiClient _api;

  Future<PagedResult<Appointment>> list({
    String? search,
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get('/appointments', query: {
      'search': search,
      'status': status?.apiValue,
      'from': from?.toUtc().toIso8601String(),
      'to': to?.toUtc().toIso8601String(),
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(Appointment.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<Appointment> get(int id) async => Appointment.fromJson((await _api.get('/appointments/$id')).map);

  Future<Appointment> create(AppointmentInput input) async =>
      Appointment.fromJson((await _api.post('/appointments', body: input.toCreateJson())).map);

  Future<Appointment> update(int id, AppointmentInput input) async =>
      Appointment.fromJson((await _api.patch('/appointments/$id', body: input.toUpdateJson())).map);

  Future<Appointment> confirm(int id) async => Appointment.fromJson((await _api.post('/appointments/$id/confirm')).map);

  Future<Appointment> cancel(int id, {String? reason}) async =>
      Appointment.fromJson((await _api.post('/appointments/$id/cancel', body: {'reason': reason})).map);
}
