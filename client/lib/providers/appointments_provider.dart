import '../models/appointment.dart';
import '../models/paged_result.dart';
import '../services/appointments_service.dart';
import '../utils/status_labels.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de citas: búsqueda, filtros de estado y fechas, paginación y carga.
class AppointmentsProvider extends PagedListProvider<Appointment> {
  AppointmentsProvider(this._service);

  final AppointmentsService _service;

  AppointmentStatus? _statusFilter;
  DateTime? _from;
  DateTime? _to;

  AppointmentStatus? get statusFilter => _statusFilter;
  DateTime? get from => _from;
  DateTime? get to => _to;

  @override
  bool get hasSearch => super.hasSearch || _statusFilter != null || _from != null || _to != null;

  /// Aplica los filtros y vuelve a la primera página.
  Future<void> setFilters({AppointmentStatus? status, DateTime? from, DateTime? to}) {
    _statusFilter = status;
    _from = from;
    _to = to;
    return load(page: 1);
  }

  @override
  Future<PagedResult<Appointment>> fetch({required String search, required int page}) => _service.list(
        search: search,
        status: _statusFilter,
        from: _from,
        to: _to,
        page: page,
      );
}
