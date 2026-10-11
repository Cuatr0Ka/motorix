import '../models/paged_result.dart';
import '../models/vehicle.dart';
import 'api_client.dart';

class VehiclesService {
  const VehiclesService(this._api);

  final ApiClient _api;

  Future<PagedResult<Vehicle>> list({String? search, int? clientId, int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/vehicles', query: {
      'search': search,
      'clientId': clientId,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(Vehicle.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<Vehicle> get(int id) async => Vehicle.fromJson((await _api.get('/vehicles/$id')).map);

  Future<Vehicle> create(VehicleInput input) async =>
      Vehicle.fromJson((await _api.post('/vehicles', body: input.toJson())).map);

  /// Edita un vehículo (incluye el cambio de propietario). Un kilometraje menor al registrado solo se
  /// acepta con [mileageCorrection], que representa la confirmación explícita de la persona.
  Future<Vehicle> update(int id, VehicleInput input, {bool mileageCorrection = false}) async {
    final response = await _api.patch('/vehicles/$id', body: {
      ...input.toJson(),
      if (mileageCorrection) 'mileageCorrection': true,
    });
    return Vehicle.fromJson(response.map);
  }
}
