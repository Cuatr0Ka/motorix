import '../models/paged_result.dart';
import '../models/user.dart';
import '../services/users_service.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de usuarios: búsqueda, paginación y carga.
class UsersProvider extends PagedListProvider<AppUser> {
  UsersProvider(this._service);

  final UsersService _service;

  @override
  Future<PagedResult<AppUser>> fetch({required String search, required int page}) =>
      _service.list(search: search, page: page);
}
