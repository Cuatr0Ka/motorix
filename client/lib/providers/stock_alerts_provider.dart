import 'package:flutter/foundation.dart';

import '../models/part.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';

/// Alertas de stock bajo para el administrador. Se consultan al iniciar la sesión, al abrir Inventario y
/// después de cada movimiento (sin canales externos ni tiempo real). Si la consulta falla se conserva el
/// último resultado y se guarda el mensaje de error.
class StockAlertsProvider extends ChangeNotifier {
  StockAlertsProvider(this._service);

  final PartsService _service;

  StockAlerts _alerts = StockAlerts.none;
  String? _error;
  bool _loading = false;
  bool _loaded = false;

  StockAlerts get alerts => _alerts;
  String? get error => _error;
  bool get loading => _loading;

  /// Ya se consultó al menos una vez (para distinguir «sin alertas» de «todavía no se sabe»).
  bool get loaded => _loaded;
  int get count => _alerts.count;
  int get outOfStock => _alerts.outOfStock;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _alerts = await _service.alerts();
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudieron consultar las alertas de stock.';
    }
    _loading = false;
    notifyListeners();
  }

  /// Limpia el estado al cerrar la sesión para no mostrar alertas a otra persona.
  void clear() {
    _alerts = StockAlerts.none;
    _error = null;
    _loaded = false;
    _loading = false;
    notifyListeners();
  }
}
