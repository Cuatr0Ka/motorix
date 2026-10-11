import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/maintenance.dart';
import '../services/api_client.dart';
import '../services/vehicles_service.dart';

/// Estado del historial de un vehículo: carga inicial, "cargar más" y errores en español.
class VehicleHistoryProvider extends ChangeNotifier {
  VehicleHistoryProvider(this.service, this.vehicleId, {this.pageSize = 20});

  final VehiclesService service;
  final int vehicleId;
  final int pageSize;

  final List<HistoryEntry> _entries = [];
  Maintenance? _pendingMaintenance;
  int _total = 0;
  int _page = 0;
  String? _error;
  bool _loading = false;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);
  Maintenance? get pendingMaintenance => _pendingMaintenance;
  int get total => _total;
  String? get error => _error;
  bool get loading => _loading;
  bool get isEmpty => !_loading && _error == null && _entries.isEmpty;
  bool get hasMore => _entries.length < _total;

  /// Carga (o recarga) la primera página.
  Future<void> load() async {
    _entries.clear();
    _page = 0;
    await _fetch(1);
  }

  /// Agrega la siguiente página al final de la lista.
  Future<void> loadMore() async {
    if (_loading || !hasMore) return;
    await _fetch(_page + 1);
  }

  Future<void> _fetch(int page) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await service.history(vehicleId, page: page, pageSize: pageSize);
      _entries.addAll(result.entries);
      _pendingMaintenance = result.pendingMaintenance;
      _total = result.total;
      _page = page;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _loading = false;
    notifyListeners();
  }
}
