import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notice.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';

/// Avisos del centro de notificaciones. Se consultan al iniciar la sesión, al cambiar de sección y cada 60
/// segundos mientras la sesión esté abierta (sin tiempo real por empuje). Si la consulta falla se conserva el
/// último resultado y se guarda el mensaje de error.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._service, {this.interval = const Duration(seconds: 60)});

  final NotificationsService _service;

  /// Cada cuánto se actualiza el contador mientras la sesión está abierta.
  final Duration interval;

  NoticesSummary _summary = NoticesSummary.empty;
  String? _error;
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  Timer? _timer;

  /// Evita que una respuesta lenta pise a otra más reciente (o a un `clear`).
  int _generation = 0;

  NoticesSummary get summary => _summary;
  String? get error => _error;
  bool get loading => _loading;

  /// Ya se consultó al menos una vez (distingue «sin avisos» de «todavía no se sabe»).
  bool get loaded => _loaded;

  /// Total de avisos no leídos: el número de la campana.
  int get unread => _summary.unread;
  bool get hasCriticalUnread => _summary.hasCriticalUnread;
  bool get isRunning => _timer?.isActive ?? false;

  /// Consulta ahora y programa la actualización periódica. Llamarlo otra vez reinicia el temporizador.
  void start() {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  /// Detiene la actualización periódica sin borrar los avisos.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = await _service.fetch();
      if (generation != _generation) return;
      _summary = result;
      _loaded = true;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'No se pudieron consultar los avisos.';
    }
    _loading = false;
    _notify();
  }

  /// Marca avisos como leídos. Se actualiza de inmediato en pantalla (el contador baja al instante) y después se
  /// reconcilia con el servidor; si falla, se restaura el estado anterior y se devuelve el mensaje de error.
  Future<String?> markRead(List<String> keys) async {
    final pending = keys.toSet();
    final before = _summary;
    final unreadKeys = {
      for (final group in before.groups)
        for (final item in group.items)
          if (!item.read && pending.contains(item.key)) item.key,
    };
    if (unreadKeys.isEmpty) return null;

    _summary = _withRead(before, unreadKeys);
    _notify();
    try {
      final result = await _service.markRead(unreadKeys.toList());
      if (!_disposed) {
        _summary = _summary.copyWith(unread: result.unread);
        _notify();
      }
      return null;
    } on ApiException catch (e) {
      return _restore(before, e.message);
    } catch (_) {
      return _restore(before, 'No se pudo marcar el aviso como leído.');
    }
  }

  String _restore(NoticesSummary before, String message) {
    _summary = before;
    _notify();
    return message;
  }

  /// Copia del resumen con los avisos indicados como leídos y los contadores de cada grupo recalculados.
  NoticesSummary _withRead(NoticesSummary summary, Set<String> keys) {
    var unread = summary.unread;
    final groups = <NoticeGroup>[];
    for (final group in summary.groups) {
      var changed = 0;
      final items = <AppNotice>[];
      for (final item in group.items) {
        if (!item.read && keys.contains(item.key)) {
          changed += 1;
          items.add(item.copyWith(read: true));
        } else {
          items.add(item);
        }
      }
      unread -= changed;
      groups.add(group.copyWith(unread: group.unread - changed, items: items));
    }
    return summary.copyWith(unread: unread < 0 ? 0 : unread, groups: groups);
  }

  /// Detiene el temporizador y limpia el estado al cerrar la sesión, para no mostrar avisos a otra persona.
  void clear() {
    stop();
    _generation += 1;
    _summary = NoticesSummary.empty;
    _error = null;
    _loaded = false;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
