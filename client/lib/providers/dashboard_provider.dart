import 'package:flutter/foundation.dart';

import '../models/dashboard.dart';
import '../services/api_client.dart';
import '../services/dashboard_service.dart';

/// Estado del panel de control: carga, error en español y actualización manual. Si una actualización falla se
/// conservan los últimos datos y se informa el error.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._service);

  final DashboardService _service;

  Dashboard? _dashboard;
  String? _error;
  bool _loading = false;

  Dashboard? get dashboard => _dashboard;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _dashboard = await _service.get();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _loading = false;
    notifyListeners();
  }
}
