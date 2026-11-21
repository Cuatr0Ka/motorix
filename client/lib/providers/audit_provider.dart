import 'package:flutter/foundation.dart';

import '../models/audit_entry.dart';
import '../services/api_client.dart';
import '../services/audit_service.dart';

/// Bitácora con filtros (fecha, usuario y acción) y paginación.
class AuditProvider extends ChangeNotifier {
  AuditProvider(this._service);

  final AuditService _service;

  AuditPage? _page;
  List<({int id, String name})> _users = const [];
  String? _error;
  bool _loading = false;
  String _from = '';
  String _to = '';
  int? _userId;
  String? _action;
  int _pageNumber = 1;
  int _requestId = 0;
  bool _disposed = false;

  AuditPage? get page => _page;
  List<({int id, String name})> get users => _users;
  String? get error => _error;
  bool get loading => _loading;
  String get from => _from;
  String get to => _to;
  int? get userId => _userId;
  String? get action => _action;
  bool get hasFilters => _from.isNotEmpty || _to.isNotEmpty || _userId != null || _action != null;

  /// Carga la primera página y, una sola vez, las personas para el filtro.
  Future<void> init() async {
    if (_users.isEmpty) {
      try {
        _users = await _service.users();
      } catch (_) {
        _users = const [];
      }
    }
    await load(page: 1);
  }

  Future<void> load({int? page}) async {
    if (page != null) _pageNumber = page;
    final id = ++_requestId;
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = await _service.list(
        from: _from.isEmpty ? null : _from,
        to: _to.isEmpty ? null : _to,
        userId: _userId,
        action: _action,
        page: _pageNumber,
      );
      if (id != _requestId) return;
      _page = result;
    } on ApiException catch (e) {
      if (id != _requestId) return;
      _error = e.message;
    } catch (_) {
      if (id != _requestId) return;
      _error = 'No se pudo consultar la bitácora.';
    }
    _loading = false;
    _notify();
  }

  /// Cambia los filtros (los que no se indican se conservan) y vuelve a la primera página.
  Future<void> applyFilters({String? from, String? to, int? userId, bool clearUser = false, String? action, bool clearAction = false}) {
    if (from != null) _from = from;
    if (to != null) _to = to;
    if (clearUser) _userId = null;
    if (userId != null) _userId = userId;
    if (clearAction) _action = null;
    if (action != null) _action = action;
    return load(page: 1);
  }

  Future<void> clearFilters() {
    _from = '';
    _to = '';
    _userId = null;
    _action = null;
    return load(page: 1);
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
