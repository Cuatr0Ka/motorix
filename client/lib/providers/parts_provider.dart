import '../models/paged_result.dart';
import '../models/part.dart';
import '../services/parts_service.dart';
import '../utils/status_labels.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de inventario: búsqueda, filtros de estado de stock y activas, paginación y carga.
class PartsProvider extends PagedListProvider<Part> {
  PartsProvider(this._service);

  final PartsService _service;

  StockStatus? _stockFilter;
  bool? _activeFilter;

  StockStatus? get stockFilter => _stockFilter;
  bool? get activeFilter => _activeFilter;

  @override
  bool get hasSearch => super.hasSearch || _stockFilter != null || _activeFilter != null;

  /// Aplica los filtros y vuelve a la primera página.
  Future<void> setFilters({StockStatus? stockStatus, bool? active}) {
    _stockFilter = stockStatus;
    _activeFilter = active;
    return load(page: 1);
  }

  @override
  Future<PagedResult<Part>> fetch({required String search, required int page}) =>
      _service.list(search: search, stockStatus: _stockFilter, active: _activeFilter, page: page);
}
