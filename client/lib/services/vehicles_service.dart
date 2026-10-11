import '../models/history_entry.dart';
import '../models/maintenance.dart';
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

  /// Historial de servicios del vehículo (órdenes Terminadas o Entregadas, la más reciente primero).
  Future<VehicleHistory> history(int vehicleId, {int page = 1, int pageSize = 20}) async {
    final response = await _api.get('/vehicles/$vehicleId/history', query: {'page': page, 'pageSize': pageSize});
    final data = response.map;
    return VehicleHistory(
      entries: ((data['entries'] as List?) ?? const [])
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: response.total,
      pendingMaintenance: data['pendingMaintenance'] == null
          ? null
          : Maintenance.fromJson(Map<String, dynamic>.from(data['pendingMaintenance'] as Map)),
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
