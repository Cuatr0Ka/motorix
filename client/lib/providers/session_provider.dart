import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum SessionStatus { signedOut, signingIn, signedIn }

/// Estado de la sesión. El token vive solo en memoria: al cerrar la aplicación se vuelve a iniciar sesión.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._api, this._auth) {
    _api.onSessionExpired = _handleExpired;
  }

  final ApiClient _api;
  final AuthService _auth;

  SessionStatus _status = SessionStatus.signedOut;
  AppUser? _user;
  String? _error;
  String? _notice;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;
  bool get isLoading => _status == SessionStatus.signingIn;

  /// Último error de inicio de sesión, listo para mostrar.
  String? get error => _error;

  /// Aviso informativo en la pantalla de acceso (por ejemplo, sesión vencida).
  String? get notice => _notice;

  Future<bool> login(String identifier, String password) async {
    _status = SessionStatus.signingIn;
    _error = null;
    _notice = null;
    notifyListeners();
    try {
      final result = await _auth.login(identifier, password);
      _api.token = result.token;
      _user = result.user;
      _status = SessionStatus.signedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _status = SessionStatus.signedOut;
    notifyListeners();
    return false;
  }

  void logout() {
    _clear();
    notifyListeners();
  }

  /// Actualiza los datos de la persona autenticada (por ejemplo, tras un cambio de rol).
  Future<void> refreshProfile() async {
    try {
      _user = await _auth.me();
      notifyListeners();
    } on ApiException {
      // Si la sesión ya no es válida, el cliente HTTP avisa mediante onSessionExpired.
    }
  }

  void _handleExpired() {
    if (!isSignedIn) return;
    _clear();
    _notice = 'Tu sesión expiró o tu cuenta ya no está disponible. Inicia sesión de nuevo.';
    notifyListeners();
  }

  void _clear() {
    _api.token = null;
    _user = null;
    _error = null;
    _notice = null;
    _status = SessionStatus.signedOut;
  }
}
