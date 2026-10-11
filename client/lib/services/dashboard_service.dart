import '../models/dashboard.dart';
import 'api_client.dart';

/// Consumo del panel de control (solo administración).
class DashboardService {
  const DashboardService(this._api);

  final ApiClient _api;

  Future<Dashboard> get() async => Dashboard.fromJson((await _api.get('/dashboard')).map);
}
