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
