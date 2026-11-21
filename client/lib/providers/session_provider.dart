import 'package:flutter/foundation.dart';

import '../models/terms.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/terms_service.dart';

enum SessionStatus { signedOut, signingIn, signedIn }

/// Estado de la sesión. El token vive solo en memoria: al cerrar la aplicación se vuelve a iniciar sesión.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._api, this._auth, [this._terms]) {
    _api.onSessionExpired = _handleExpired;
    _api.onTermsRequired = _handleTermsRequired;
    _api.onSessionInactive = logoutInactive;
  }

  final ApiClient _api;
  final AuthService _auth;
  final TermsService? _terms;

  SessionStatus _status = SessionStatus.signedOut;
  AppUser? _user;
  String? _error;
  String? _notice;

  // Términos y condiciones (Sprint 7): mientras estén pendientes no se muestra la aplicación, solo su aceptación.
  bool _termsRequired = false;
  TermsDocument? _pendingTerms;
  String? _termsError;
  bool _termsBusy = false;

  /// La persona debe aceptar los términos vigentes antes de usar la aplicación.
  bool get termsPending => isSignedIn && _termsRequired;
  TermsDocument? get pendingTerms => _pendingTerms;
  String? get termsError => _termsError;
  bool get termsBusy => _termsBusy;

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
      await _checkTerms();
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

  /// Consulta la versión vigente de los términos y marca si la persona debe aceptarla. Un error de red deja la
  /// aceptación como pendiente (con «Reintentar»): no se abre la aplicación sin comprobarlo.
  Future<void> _checkTerms() async {
    final terms = _terms;
    if (terms == null) return;
    _termsError = null;
    try {
      final current = await terms.current();
      _termsRequired = !current.accepted;
      _pendingTerms = current.accepted ? null : current;
    } on ApiException catch (e) {
      _termsRequired = true;
      _pendingTerms = null;
      _termsError = e.message;
    } catch (_) {
      _termsRequired = true;
      _pendingTerms = null;
      _termsError = 'No se pudo consultar los términos y condiciones.';
    }
  }

  /// Vuelve a consultar los términos (botón «Reintentar» de la pantalla de aceptación).
  Future<void> reloadTerms() async {
    _termsBusy = true;
    notifyListeners();
    await _checkTerms();
    _termsBusy = false;
    notifyListeners();
  }

  /// Acepta la versión pendiente y abre la aplicación. Si falla, conserva la pantalla con el error.
  Future<void> acceptTerms() async {
    final terms = _terms;
    final pending = _pendingTerms;
    if (terms == null || pending == null) return;
    _termsBusy = true;
    _termsError = null;
    notifyListeners();
    try {
      await terms.accept(pending.id);
      _termsRequired = false;
      _pendingTerms = null;
    } on ApiException catch (e) {
      _termsError = e.message;
      // 409: la versión cambió mientras se leía; se vuelve a cargar la vigente.
      if (e.code == 'TERMS_VERSION_OUTDATED') await _checkTerms();
    } catch (_) {
      _termsError = 'No se pudo registrar la aceptación. Inténtalo de nuevo.';
    }
    _termsBusy = false;
    notifyListeners();
  }

  /// Cierra la sesión por inactividad (a los 30 minutos sin actividad o cuando el servidor responde SESSION_INACTIVE).
  void logoutInactive() {
    if (!isSignedIn) return;
    _clear();
    _notice = 'Tu sesión se cerró por inactividad. Inicia sesión de nuevo.';
    notifyListeners();
  }

  /// Rechaza los términos: cierra la sesión con un aviso en el acceso.
  void rejectTerms() {
    _clear();
    _notice = 'Para usar Motorix debes aceptar los términos y condiciones.';
    notifyListeners();
  }

  /// Un 403 TERMS_NOT_ACCEPTED a mitad de sesión (se publicó una versión nueva): vuelve a pedir la aceptación.
  void _handleTermsRequired() {
    if (!isSignedIn || _termsRequired) return;
    _termsRequired = true;
    notifyListeners();
    reloadTerms();
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
    _termsRequired = false;
    _pendingTerms = null;
    _termsError = null;
    _termsBusy = false;
    _status = SessionStatus.signedOut;
  }
}
