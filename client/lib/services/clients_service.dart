import '../models/client.dart';
import '../models/paged_result.dart';
import 'api_client.dart';

class ClientsService {
  const ClientsService(this._api);

  final ApiClient _api;

  Future<PagedResult<Client>> list({String? search, int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/clients', query: {
      'search': search,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(Client.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<Client> get(int id) async => Client.fromJson((await _api.get('/clients/$id')).map);

  /// Registra un cliente. Si el teléfono ya existe la API responde `PHONE_DUPLICATE` y hay que
  /// repetir la llamada con [confirmDuplicatePhone] en verdadero tras la confirmación de la persona.
  Future<Client> create(ClientInput input, {bool confirmDuplicatePhone = false}) async {
    final response = await _api.post('/clients', body: {
      ...input.toJson(),
      if (confirmDuplicatePhone) 'confirmDuplicatePhone': true,
    });
    return Client.fromJson(response.map);
  }

  /// Actualiza un cliente existente con las mismas reglas de duplicados que el alta.
  Future<Client> update(int id, ClientInput input, {bool confirmDuplicatePhone = false}) async {
    final response = await _api.patch('/clients/$id', body: {
      ...input.toJson(),
      if (confirmDuplicatePhone) 'confirmDuplicatePhone': true,
    });
    return Client.fromJson(response.map);
  }
}
