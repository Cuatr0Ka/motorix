import '../models/report.dart';
import 'api_client.dart';

/// Consumo de la API de reportes (solo administración).
class ReportsService {
  const ReportsService(this._api);

  final ApiClient _api;

  Map<String, dynamic> _query(ReportPeriod period) => {'from': period.fromText, 'to': period.toText};

  Future<List<Map<String, dynamic>>> _items(String name, ReportPeriod period) async {
    final data = (await _api.get('/reports/$name', query: _query(period))).map;
    return [for (final item in (data['items'] as List)) Map<String, dynamic>.from(item as Map)];
  }

  Future<IncomeReport> income(ReportPeriod period) async =>
      IncomeReport.fromJson((await _api.get('/reports/income', query: _query(period))).map);

  Future<List<ServiceStat>> services(ReportPeriod period) async => (await _items('services', period)).map(ServiceStat.fromJson).toList();

  Future<List<MechanicStat>> productivity(ReportPeriod period) async =>
      (await _items('productivity', period)).map(MechanicStat.fromJson).toList();

  Future<PartsReport> parts(ReportPeriod period) async => PartsReport.fromJson((await _api.get('/reports/parts', query: _query(period))).map);

  Future<List<RotationStat>> rotation(ReportPeriod period) async => (await _items('rotation', period)).map(RotationStat.fromJson).toList();

  /// Descarga el reporte como libro de Excel (los mismos datos y periodo que la pantalla).
  Future<DownloadedFile> exportXlsx(String name, ReportPeriod period) =>
      _api.download('/reports/$name', query: {..._query(period), 'format': 'xlsx'});
}
