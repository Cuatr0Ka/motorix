import '../models/paged_result.dart';
import '../models/service_order.dart';
import '../services/orders_service.dart';
import '../utils/status_labels.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de órdenes: búsqueda, filtros de estado y mecánico, paginación y carga.
/// Se usa tanto en «Órdenes» (recepción y administración) como en «Mis órdenes» (mecánico); en este
/// último caso el servidor limita el resultado a las órdenes asignadas a quien consulta.
class OrdersProvider extends PagedListProvider<ServiceOrder> {
  OrdersProvider(this._service);

  final OrdersService _service;

  OrderStatus? _statusFilter;
  int? _mechanicFilter;

  OrderStatus? get statusFilter => _statusFilter;
  int? get mechanicFilter => _mechanicFilter;

  @override
  bool get hasSearch => super.hasSearch || _statusFilter != null || _mechanicFilter != null;

  /// Aplica los filtros y vuelve a la primera página.
  Future<void> setFilters({OrderStatus? status, int? mechanicId}) {
    _statusFilter = status;
    _mechanicFilter = mechanicId;
    return load(page: 1);
  }

  @override
  Future<PagedResult<ServiceOrder>> fetch({required String search, required int page}) =>
      _service.list(search: search, status: _statusFilter, mechanicId: _mechanicFilter, page: page);
}
