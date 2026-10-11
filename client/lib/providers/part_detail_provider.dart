import 'package:flutter/foundation.dart';

import '../models/part.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';

/// Estado del detalle de una refacción: carga, errores y acciones (entrada, ajuste, activar o
/// desactivar). Cada acción devuelve el mensaje de error en español, o null si salió bien; la
/// refacción se vuelve a leer del servidor, que es la fuente de verdad.
class PartDetailProvider extends ChangeNotifier {
  PartDetailProvider(this.service, this.partId);

  final PartsService service;
  final int partId;

  Part? _part;
  String? _error;
  bool _loading = false;
  bool _busy = false;

  /// Cuántas veces cambió el inventario desde aquí (para que quien abrió el detalle actualice sus alertas).
  int changes = 0;

  Part? get part => _part;
  String? get error => _error;
  bool get loading => _loading;
  bool get busy => _busy;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _part = await service.get(partId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() action) async {
    if (_busy) return 'Hay otra acción en curso. Espera un momento.';
    _busy = true;
    notifyListeners();
    String? failure;
    try {
      await action();
      changes += 1;
      _part = await service.get(partId);
    } on ApiException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _busy = false;
    notifyListeners();
    return failure;
  }

  /// Registra una entrada de mercancía.
  Future<String?> receive(int quantity, {String? reason}) => _run(() => service.receive(partId, quantity, reason: reason));

  /// Ajusta el inventario a la cantidad contada.
  Future<String?> adjust(int countedQuantity, String reason) => _run(() => service.adjust(partId, countedQuantity, reason));

  Future<String?> setActive(bool active) => _run(() => service.setActive(partId, active));
}
