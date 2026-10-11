import '../models/user.dart';
import 'api_client.dart';

/// Resultado de un inicio de sesión correcto.
class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  /// Inicia sesión con usuario o correo en el mismo campo.
  Future<LoginResult> login(String identifier, String password) async {
    final response = await _api.post('/auth/login', body: {
      'identifier': identifier.trim(),
      'password': password,
    });
    final data = response.map;
    return LoginResult(
      token: '${data['token']}',
      user: AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  Future<AppUser> me() async {
    final response = await _api.get('/auth/me');
    return AppUser.fromJson(response.map);
  }

  /// Cambia la contraseña de la persona autenticada.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
