import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import '../providers/reports_provider.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../utils/link_opener.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/period_selector.dart';
import '../widgets/state_views.dart';

/// Reportes del taller (solo administración): ingresos, servicios y productividad, y costo, margen y rotación de
/// refacciones. Cada pestaña se calcula en el servidor para el periodo elegido y se exporta a Excel.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) context.read<ReportsProvider>().selectTab(ReportTab.values[_tabs.index]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReportsProvider>().selectTab(ReportTab.values[_tabs.index]);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final provider = context.read<ReportsProvider>();
    final opener = context.read<LinkOpener>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paths = await provider.exportCurrent();
      if (!mounted) return;
      final folder = _folderOf(paths.first);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(paths.length == 1 ? 'Archivo guardado en ${paths.first}' : 'Archivos guardados en $folder'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: 'Abrir carpeta', onPressed: () => opener.open(Uri.file(folder).toString())),
        ));
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    } catch (_) {
      if (mounted) showFailure(context, 'No se pudo guardar el archivo. Revisa los permisos de la carpeta de descargas.');
    }
  }

  static String _folderOf(String path) {
    final cut = path.lastIndexOf(RegExp(r'[\\/]'));
    return cut > 0 ? path.substring(0, cut) : path;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Reportes',
            subtitle: 'Ingresos, servicios, productividad y refacciones del periodo',
            actions: [
              FilledButton.icon(
                key: const ValueKey('exportar-excel'),
                onPressed: provider.exporting ? null : _export,
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(provider.exporting ? 'Exportando…' : 'Exportar Excel'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PeriodSelector(period: provider.period, preset: provider.preset, onSelect: provider.selectPeriod),
          const SizedBox(height: AppSpacing.lg),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(key: ValueKey('pestana-ingresos'), text: 'Ingresos'),
              Tab(key: ValueKey('pestana-servicios'), text: 'Servicios y productividad'),
              Tab(key: ValueKey('pestana-refacciones'), text: 'Refacciones y rotación'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_IncomeTab(), _OperationTab(), _PartsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Envoltura común: cargando, error con «Reintentar» y estado vacío «No hay datos en este periodo».
class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.ready, required this.empty, required this.builder});

  final ReportTab tab;
  final bool ready;
  final bool empty;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final error = provider.errorOf(tab);
    if (!ready) {
      if (error != null) return ErrorView(message: error, onRetry: () => provider.loadTab(tab, force: true));
      return const LoadingView();
    }
    if (empty) return const EmptyView(message: 'No hay datos en este periodo');
    return builder(context);
  }
}

class _IncomeTab extends StatelessWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final report = provider.income;
    return _TabBody(
      tab: ReportTab.income,
      ready: report != null,
      empty: report?.isEmpty ?? false,
      builder: (context) => ListView(
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              _StatCard(key: const ValueKey('ingresos-total'), label: 'Total de ingresos', value: formatMoney(report!.total), icon: Icons.payments_outlined),
              _StatCard(key: const ValueKey('ingresos-pagos'), label: 'Pagos registrados', value: '${report.paymentsCount}', icon: Icons.receipt_long_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Ingresos por día', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SizedBox(key: const ValueKey('ingresos-grafica'), height: 240, child: _DayBars(rows: report.byDay)),
          const SizedBox(height: AppSpacing.xl),
          Text('Ingresos por método de pago', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SimpleTable(
            keyPrefix: 'metodo',
            headers: const ['Método de pago', 'Pagos', 'Total'],
            numeric: const [false, true, true],
            rows: [
              for (final row in report.byMethod) [PaymentMethod.fromApi(row.label).label, '${row.payments}', formatMoney(row.total)],
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationTab extends StatelessWidget {
  const _OperationTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final services = provider.services;
    final mechanics = provider.mechanics;
    return _TabBody(
      tab: ReportTab.operation,
      ready: services != null && mechanics != null,
      empty: (services?.isEmpty ?? false) && (mechanics?.isEmpty ?? false),
      builder: (context) => ListView(
        children: [
          Text('Servicios más frecuentes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SimpleTable(
            keyPrefix: 'servicio',
            headers: const ['Servicio', 'Veces realizado', 'Importe'],
            numeric: const [false, true, true],
            rows: [for (final s in services!) [s.name, '${s.times}', formatMoney(s.amount)]],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Productividad por mecánico', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SimpleTable(
            keyPrefix: 'mecanico',
            headers: const ['Mecánico', 'Órdenes terminadas', 'Mano de obra'],
            numeric: const [false, true, true],
            rows: [for (final m in mechanics!) [m.name, '${m.ordersFinished}', formatMoney(m.laborAmount)]],
          ),
        ],
      ),
    );
  }
}

class _PartsTab extends StatelessWidget {
  const _PartsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final parts = provider.parts;
    final rotation = provider.rotation;
    final theme = Theme.of(context);
    return _TabBody(
      tab: ReportTab.parts,
      ready: parts != null && rotation != null,
      empty: (parts?.items.isEmpty ?? false) && (rotation?.isEmpty ?? false),
      builder: (context) => ListView(
        children: [
          Text('Costo y margen por refacción', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SimpleTable(
            keyPrefix: 'refaccion',
            headers: const ['Refacción', 'Unidades', 'Ingreso', 'Costo', 'Margen', 'Margen %'],
            numeric: const [false, true, true, true, true, true],
            rows: [
              for (final p in parts!.items)
                [
                  p.name,
                  '${p.units}',
                  formatMoney(p.revenue),
                  p.noCost ? null : formatMoney(p.cost!),
                  p.noCost ? null : formatMoney(p.margin!),
                  p.noCost ? null : '${p.marginPercent ?? '—'}%',
                ],
            ],
            // Una refacción sin precio de compra lleva el chip ámbar «Sin costo» en lugar de costo y margen.
            noCostCell: const _NoCostChip(),
            noCostColumn: 3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Total (sin las refacciones «Sin costo»): ingreso ${formatMoney(parts.revenue)} · costo ${formatMoney(parts.cost)} · margen ${formatMoney(parts.margin)}'
            '${parts.noCostLines > 0 ? ' · ${parts.noCostLines} refacción(es) sin costo' : ''}',
            key: const ValueKey('refacciones-totales'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Rotación del inventario', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _SimpleTable(
            keyPrefix: 'rotacion',
            headers: const ['Refacción', 'Salidas', 'Existencia inicial', 'Existencia final', 'Promedio', 'Rotación'],
            numeric: const [false, true, true, true, true, true],
            rows: [
              for (final r in rotation!) [r.name, '${r.out}', '${r.stockStart}', '${r.stockEnd}', r.averageStock, r.rotation ?? '—'],
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip ámbar «Sin costo»: el texto siempre acompaña al color.
class _NoCostChip extends StatelessWidget {
  const _NoCostChip();

  @override
  Widget build(BuildContext context) => const Chip(
        key: ValueKey('sin-costo'),
        label: Text('Sin costo'),
        visualDensity: VisualDensity.compact,
        backgroundColor: Color(0xFFF6E7C9),
        side: BorderSide(color: AppColors.warning),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabla simple y accesible: encabezado, filas alternadas y columnas numéricas alineadas a la derecha. Una celda nula en una fila
/// se sustituye por [noCostCell] cuando se indica.
class _SimpleTable extends StatelessWidget {
  const _SimpleTable({required this.keyPrefix, required this.headers, required this.rows, required this.numeric, this.noCostCell, this.noCostColumn});

  final String keyPrefix;
  final List<String> headers;
  final List<bool> numeric;
  final List<List<String?>> rows;
  final Widget? noCostCell;

  /// Columna donde se muestra [noCostCell]; en las demás celdas nulas se muestra «—».
  final int? noCostColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(Widget child, int column) => Expanded(
          flex: column == 0 ? 3 : 2,
          child: Align(alignment: numeric[column] ? Alignment.centerRight : Alignment.centerLeft, child: child),
        );

    if (rows.isEmpty) return Text('Sin datos en este periodo', style: theme.textTheme.bodySmall);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.outline), borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  cell(Text(headers[i], style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)), i),
              ],
            ),
          ),
          for (var r = 0; r < rows.length; r++)
            Container(
              key: ValueKey('$keyPrefix-$r'),
              color: r.isEven ? AppColors.surface : AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    cell(rows[r][i] == null ? (i == noCostColumn && noCostCell != null ? noCostCell! : const Text('—')) : Text(rows[r][i]!, style: theme.textTheme.bodyMedium), i),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Barras de ingresos por día.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.rows});

  final List<IncomeRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [for (final row in rows) double.tryParse(row.total) ?? 0];
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    final top = max <= 0 ? 1.0 : max * 1.15;
    final labelEvery = (rows.length / 10).ceil().clamp(1, 1000);
    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => SideTitleWidget(meta: meta, child: Text(formatMoney(value.toStringAsFixed(0)).replaceAll('.00', ''), style: theme.textTheme.bodySmall)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length || index % labelEvery != 0) return const SizedBox.shrink();
                return SideTitleWidget(meta: meta, child: Text(rows[index].label.substring(5), style: theme.textTheme.bodySmall));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: values[i], width: rows.length > 45 ? 6 : 18, color: AppColors.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ]),
        ],
      ),
    );
  }
}
