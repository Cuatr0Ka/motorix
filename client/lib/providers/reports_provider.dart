import 'package:flutter/foundation.dart';

import '../models/report.dart';
import '../services/api_client.dart';
import '../services/reports_service.dart';
import '../utils/file_saver.dart';

/// Pestañas de la pantalla de reportes.
enum ReportTab { income, operation, parts }

/// Periodo elegido y datos de cada pestaña. Cada pestaña se carga al abrirla; si cambia el periodo se descartan los datos y
/// se vuelve a cargar solo la pestaña visible.
class ReportsProvider extends ChangeNotifier {
  ReportsProvider(this._service, this._saver, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _period = ReportPeriod.month(_clock());
  }

  final ReportsService _service;
  final FileSaver _saver;
  final DateTime Function() _clock;

  late ReportPeriod _period;
  String _preset = 'month';
  ReportTab _tab = ReportTab.income;
  final Map<ReportTab, String?> _errors = {};
  final Set<ReportTab> _loading = {};
  bool _exporting = false;
  bool _disposed = false;
  int _generation = 0;

  IncomeReport? income;
  List<ServiceStat>? services;
  List<MechanicStat>? mechanics;
  PartsReport? parts;
  List<RotationStat>? rotation;

  ReportPeriod get period => _period;
  String get preset => _preset;
  ReportTab get tab => _tab;
  bool get exporting => _exporting;
  bool isLoading(ReportTab tab) => _loading.contains(tab);
  String? errorOf(ReportTab tab) => _errors[tab];

  /// Mensaje de error del periodo (más de un año) o null si es válido.
  static String? validate(ReportPeriod period) {
    if (period.to.isBefore(period.from)) return 'La fecha final no puede ser anterior a la inicial.';
    if (period.days > 366) return 'El periodo no puede pasar de un año.';
    return null;
  }

  /// Elige un periodo rápido (`today`, `week`, `month`) o uno propio (`range`, con [custom]). Devuelve el error del
  /// periodo, si lo hay (en ese caso no se aplica).
  Future<String?> selectPeriod(String preset, {ReportPeriod? custom}) async {
    final now = _clock();
    final next = switch (preset) {
      'today' => ReportPeriod.today(now),
      'week' => ReportPeriod.week(now),
      'month' => ReportPeriod.month(now),
      _ => custom ?? _period,
    };
    final problem = validate(next);
    if (problem != null) return problem;
    _preset = preset;
    _period = next;
    _generation += 1;
    income = null;
    services = null;
    mechanics = null;
    parts = null;
    rotation = null;
    _errors.clear();
    notifyListeners();
    await loadTab(_tab);
    return null;
  }

  Future<void> selectTab(ReportTab tab) async {
    _tab = tab;
    notifyListeners();
    await loadTab(tab);
  }

  /// Carga los datos de la pestaña si todavía no están (o fuerza con [force]).
  Future<void> loadTab(ReportTab tab, {bool force = false}) async {
    if (_loading.contains(tab)) return;
    if (!force && _hasData(tab)) return;
    final generation = _generation;
    _loading.add(tab);
    _errors[tab] = null;
    _notify();
    try {
      switch (tab) {
        case ReportTab.income:
          final result = await _service.income(_period);
          if (generation == _generation) income = result;
        case ReportTab.operation:
          final results = await Future.wait([_service.services(_period), _service.productivity(_period)]);
          if (generation == _generation) {
            services = results[0] as List<ServiceStat>;
            mechanics = results[1] as List<MechanicStat>;
          }
        case ReportTab.parts:
          final results = await Future.wait([_service.parts(_period), _service.rotation(_period)]);
          if (generation == _generation) {
            parts = results[0] as PartsReport;
            rotation = results[1] as List<RotationStat>;
          }
      }
    } on ApiException catch (e) {
      if (generation == _generation) _errors[tab] = e.message;
    } catch (_) {
      if (generation == _generation) _errors[tab] = 'No se pudo consultar el reporte.';
    }
    _loading.remove(tab);
    _notify();
  }

  bool _hasData(ReportTab tab) => switch (tab) {
        ReportTab.income => income != null,
        ReportTab.operation => services != null && mechanics != null,
        ReportTab.parts => parts != null && rotation != null,
      };

  /// Nombres de los reportes que exporta cada pestaña.
  static List<String> reportsOf(ReportTab tab) => switch (tab) {
        ReportTab.income => ['income'],
        ReportTab.operation => ['services', 'productivity'],
        ReportTab.parts => ['parts', 'rotation'],
      };

  /// Exporta a Excel los reportes de la pestaña activa con el periodo elegido y guarda los archivos. Devuelve las rutas.
  /// Lanza [ApiException] o un error de escritura con su mensaje; los datos de la pantalla no se pierden.
  Future<List<String>> exportCurrent() async {
    _exporting = true;
    _notify();
    try {
      final paths = <String>[];
      for (final name in reportsOf(_tab)) {
        final file = await _service.exportXlsx(name, _period);
        paths.add(await _saver.save(file.filename, file.bytes));
      }
      return paths;
    } finally {
      _exporting = false;
      _notify();
    }
  }

  void clear() {
    income = null;
    services = null;
    mechanics = null;
    parts = null;
    rotation = null;
    _errors.clear();
    _loading.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
