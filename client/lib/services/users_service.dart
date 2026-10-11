import '../models/paged_result.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Datos capturados al crear un usuario.
class UserInput {
  const UserInput({
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    required this.password,
  });

  final String username;
  final String name;
  final String email;
  final UserRole role;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'name': name,
        'email': email,
        'role': role.apiValue,
        'password': password,
      };
}

class UsersService {
  const UsersService(this._api);

  final ApiClient _api;

  Future<PagedResult<AppUser>> list({String? search, int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/users', query: {
      'search': search,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(AppUser.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<AppUser> create(UserInput input) async =>
      AppUser.fromJson((await _api.post('/users', body: input.toJson())).map);

  /// Cambia el rol de un usuario. Rige desde su siguiente petición.
  Future<AppUser> changeRole(int id, UserRole role) async =>
      AppUser.fromJson((await _api.patch('/users/$id', body: {'role': role.apiValue})).map);

  /// Activa o desactiva a un usuario (los usuarios no se eliminan).
  Future<AppUser> setActive(int id, bool active) async =>
      AppUser.fromJson((await _api.patch('/users/$id', body: {'active': active})).map);
}
