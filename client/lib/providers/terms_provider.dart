import 'package:flutter/foundation.dart';

import '../models/terms.dart';
import '../services/api_client.dart';
import '../services/terms_service.dart';

/// Sección «Términos» de administración: versión vigente y quién la aceptó (solo lectura).
class TermsProvider extends ChangeNotifier {
  TermsProvider(this._service);

  final TermsService _service;

  TermsDocument? _current;
  TermsAcceptancesPage? _page;
  String? _error;
  bool _loading = false;
  int _pageNumber = 1;
  bool _disposed = false;

  TermsDocument? get current => _current;
  TermsAcceptancesPage? get page => _page;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> load({int page = 1}) async {
    _loading = true;
    _error = null;
    _pageNumber = page;
    _notify();
    try {
      final results = await Future.wait([_service.current(), _service.acceptances(page: page)]);
      _current = results[0] as TermsDocument;
      _page = results[1] as TermsAcceptancesPage;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo consultar los términos y condiciones.';
    }
    _loading = false;
    _notify();
  }

  Future<void> goTo(int page) => load(page: page);

  int get pageNumber => _pageNumber;

  void clear() {
    _current = null;
    _page = null;
    _error = null;
    _loading = false;
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
