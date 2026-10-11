import '../models/maintenance.dart';
import '../models/paged_result.dart';
import '../services/api_client.dart';
import '../services/maintenance_service.dart';
import '../utils/status_labels.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado de la lista de mantenimientos pendientes (recepción y administración): búsqueda por cliente o
/// placa, filtro de indicador (Normal, Próximo, Vencido), paginación y acciones de administración
/// (editar y marcar como atendido).
class MaintenanceProvider extends PagedListProvider<Maintenance> {
  MaintenanceProvider(this._service);

  final MaintenanceService _service;

  MaintenanceIndicator? _indicatorFilter;

  MaintenanceIndicator? get indicatorFilter => _indicatorFilter;

  @override
  bool get hasSearch => super.hasSearch || _indicatorFilter != null;

  /// Aplica el filtro de indicador y vuelve a la primera página.
  Future<void> setIndicator(MaintenanceIndicator? indicator) {
    _indicatorFilter = indicator;
    return load(page: 1);
  }

  @override
  Future<PagedResult<Maintenance>> fetch({required String search, required int page}) =>
      _service.list(search: search, indicator: _indicatorFilter, page: page);

  /// Ejecuta una acción de edición y recarga la lista. Devuelve el mensaje de error en español, o null.
  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    await reload();
    return null;
  }

  Future<String?> update(int id, MaintenanceInput input) => _run(() => _service.update(id, input));

  Future<String?> attend(int id) => _run(() => _service.attend(id));
}
