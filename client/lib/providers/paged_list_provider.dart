import 'package:flutter/foundation.dart';

import '../models/paged_result.dart';
import '../services/api_client.dart';

enum LoadStatus { idle, loading, ready, error }

/// Base de los listados paginados con búsqueda: administra carga, errores, página y texto buscado.
abstract class PagedListProvider<T> extends ChangeNotifier {
  LoadStatus _status = LoadStatus.idle;
  PagedResult<T>? _result;
  String _search = '';
  int _page = 1;
  String? _error;

  /// Evita aplicar respuestas antiguas si se lanzan varias búsquedas seguidas.
  int _requestId = 0;

  LoadStatus get status => _status;
  PagedResult<T>? get result => _result;
  String get search => _search;
  int get page => _page;
  String? get error => _error;
  bool get hasSearch => _search.isNotEmpty;

  /// Pide una página al servidor con los filtros actuales.
  Future<PagedResult<T>> fetch({required String search, required int page});

  Future<void> load({String? search, int? page}) async {
    if (search != null && search != _search) {
      _search = search;
      _page = 1;
    }
    if (page != null) _page = page;

    final id = ++_requestId;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await fetch(search: _search, page: _page);
      if (id != _requestId) return;
      _result = result;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      if (id != _requestId) return;
      _error = e.message;
      _status = LoadStatus.error;
    } catch (_) {
      if (id != _requestId) return;
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> reload() => load();
}
