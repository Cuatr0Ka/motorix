import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';

/// Configuración del taller (administración). Si la consulta falla se conserva el último resultado y se guarda el error;
/// los errores del servidor al guardar se asignan al campo que corresponde (`shop.name`, `maintenance.warnDays`...).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._service);

  final SettingsService _service;

  SettingsSnapshot? _snapshot;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  bool _disposed = false;

  SettingsSnapshot? get snapshot => _snapshot;
  String? get error => _error;
  bool get loading => _loading;
  bool get saving => _saving;

  /// Errores por campo del último intento de guardar (clave `shop.name`, `maintenance.warnDays`...).
  Map<String, String> get fieldErrors => _fieldErrors;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _snapshot = await _service.fetch();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo consultar la configuración.';
    }
    _loading = false;
    _notify();
  }

  /// Guarda los cambios. Devuelve null si quedó guardado o el mensaje de error general; los errores de cada campo
  /// quedan en [fieldErrors].
  Future<String?> save(Map<String, dynamic> changes) async {
    _saving = true;
    _fieldErrors = const {};
    _notify();
    String? failure;
    try {
      _snapshot = await _service.save(changes);
    } on ApiException catch (e) {
      final byField = {for (final f in e.fieldErrors) f.field: f.message};
      if (byField.isEmpty) {
        failure = e.message;
      } else {
        _fieldErrors = byField;
        failure = e.message;
      }
    } catch (_) {
      failure = 'No se pudo guardar la configuración.';
    }
    _saving = false;
    _notify();
    return failure;
  }

  /// Quita los errores del servidor de un intento anterior (antes de validar de nuevo en pantalla).
  void clearFieldErrors() {
    if (_fieldErrors.isEmpty) return;
    _fieldErrors = const {};
    _notify();
  }

  /// Limpia el estado al cerrar la sesión.
  void clear() {
    _snapshot = null;
    _error = null;
    _loading = false;
    _saving = false;
    _fieldErrors = const {};
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
