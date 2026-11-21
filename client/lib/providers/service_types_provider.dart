import 'package:flutter/foundation.dart';

import '../models/service_type.dart';
import '../services/api_client.dart';
import '../services/service_types_service.dart';

/// Catálogo de tipos de servicio: lista de gestión (administración), opciones activas para las líneas de servicio y
/// la propuesta del próximo mantenimiento.
class ServiceTypesProvider extends ChangeNotifier {
  ServiceTypesProvider(this._service);

  final ServiceTypesService _service;

  List<ServiceType>? _items;
  List<ServiceType> _options = const [];
  String? _error;
  bool _loading = false;
  bool _disposed = false;

  /// Lista de gestión; null mientras no se ha cargado.
  List<ServiceType>? get items => _items;
  List<ServiceType> get options => _options;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _items = await _service.list();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo consultar el catálogo de tipos de servicio.';
    }
    _loading = false;
    _notify();
  }

  /// Carga los tipos activos para el selector de la línea de servicio. Si falla, el selector queda vacío (es opcional).
  Future<void> loadOptions() async {
    try {
      _options = await _service.options();
    } catch (_) {
      _options = const [];
    }
    _notify();
  }

  /// Alta. Devuelve null si quedó guardado o el mensaje de error (409 duplicado, 422 sin intervalo...).
  Future<String?> create(ServiceTypeInput input) => _change(() => _service.create(input));

  /// Edición completa del formulario (nombre e intervalos; null quita un intervalo).
  Future<String?> edit(int id, ServiceTypeInput input) => _change(() => _service.update(id, input.toJson()));

  /// Desactiva o reactiva (un tipo nunca se borra).
  Future<String?> setActive(int id, bool active) => _change(() => _service.update(id, {'active': active}));

  Future<String?> _change(Future<Object> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo guardar el tipo de servicio.';
    }
    await load();
    return null;
  }

  /// Próximo mantenimiento propuesto para la orden; null si no hay intervalos. Lanza [ApiException] si falla.
  Future<MaintenanceSuggestion?> suggestion(int orderId) => _service.suggestion(orderId);

  /// Limpia el estado al cerrar la sesión.
  void clear() {
    _items = null;
    _options = const [];
    _error = null;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
