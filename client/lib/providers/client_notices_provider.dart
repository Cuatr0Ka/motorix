import 'package:flutter/foundation.dart';

import '../models/client_notice.dart';
import '../services/api_client.dart';
import '../services/client_notices_service.dart';

/// Resultado de marcar a un cliente como avisado.
enum NotifiedOutcome {
  /// Quedó registrado (o ya lo estaba): la fila sale de la lista.
  done,

  /// El hecho ya no aplica (por ejemplo, la orden se entregó): se actualiza la lista.
  notApplicable,

  /// Falló el registro: la fila se conserva.
  failed,
}

/// Lista de clientes por avisar de la recepción. Si la consulta falla se conserva la última lista y se guarda el
/// mensaje de error.
class ClientNoticesProvider extends ChangeNotifier {
  ClientNoticesProvider(this._service);

  final ClientNoticesService _service;

  List<PendingClientNotice> _items = const [];
  int _total = 0;
  String? _error;
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;

  /// Mensaje del último intento de marcar que falló (para mostrarlo al usuario).
  String? lastFailure;

  List<PendingClientNotice> get items => _items;
  int get total => _total;
  String? get error => _error;
  bool get loading => _loading;
  bool get loaded => _loaded;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = await _service.list();
      _items = result.items;
      _total = result.total;
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo consultar la lista de clientes por avisar.';
    }
    _loading = false;
    _notify();
  }

  /// Marca al cliente como avisado. Si queda registrado la fila sale de la lista; si el hecho ya no aplica se
  /// actualiza la lista; si falla, la fila se conserva y el mensaje queda en [lastFailure].
  Future<NotifiedOutcome> markNotified(PendingClientNotice notice) async {
    lastFailure = null;
    try {
      await _service.markNotified(notice.reason, notice.factId);
      _items = _items.where((item) => item.rowKey != notice.rowKey).toList();
      _total = _total > 0 ? _total - 1 : 0;
      _notify();
      return NotifiedOutcome.done;
    } on ApiException catch (e) {
      if (e.code == 'NOTICE_NOT_APPLICABLE') {
        await load();
        return NotifiedOutcome.notApplicable;
      }
      lastFailure = e.message;
      return NotifiedOutcome.failed;
    } catch (_) {
      lastFailure = 'No se pudo registrar el aviso.';
      return NotifiedOutcome.failed;
    }
  }

  /// Limpia el estado al cerrar la sesión.
  void clear() {
    _items = const [];
    _total = 0;
    _error = null;
    _loading = false;
    _loaded = false;
    lastFailure = null;
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
