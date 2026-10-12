import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';

const _monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

/// Importe corto para los ejes: 950, 1.2k, 3.5k.
String _shortMoney(double value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '\$${k.toStringAsFixed(k >= 10 || k == k.roundToDouble() ? 0 : 1)}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

/// Color de cada estado de la orden en la dona. Sigue el tono de su chip, con un paso distinto cuando dos estados
/// comparten tono; el texto de la leyenda siempre acompaña al color.
Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.received:
      return const Color(0xFF9A8F90);
    case OrderStatus.diagnosis:
      return const Color(0xFF86AACB);
    case OrderStatus.repairing:
      return AppColors.info;
    case OrderStatus.waitingPart:
      return AppColors.warning;
    case OrderStatus.finished:
      return AppColors.success;
    case OrderStatus.delivered:
      return const Color(0xFF93B79C);
  }
}

/// Mensaje de estado vacío de una gráfica.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center));
}

/// Dona de órdenes por estado, con el total al centro y la leyenda (estado, cantidad y porcentaje) a un lado.
/// Al pasar el cursor por un tramo o un renglón de la leyenda, el centro muestra ese estado.
class OrdersByStatusDonut extends StatefulWidget {
  const OrdersByStatusDonut({super.key, required this.data});

  final List<OrderStatusCount> data;

  @override
  State<OrdersByStatusDonut> createState() => _OrdersByStatusDonutState();
}

class _OrdersByStatusDonutState extends State<OrdersByStatusDonut> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [for (final d in widget.data) (status: OrderStatus.fromApi(d.status), total: d.total)];
    final total = items.fold<int>(0, (sum, e) => sum + e.total);
    if (total == 0) return const ChartEmpty('Todavía no hay órdenes registradas.');

    final hovered = _hovered == null ? null : items[_hovered!];
    final donut = AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: double.infinity,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = response?.touchedSection?.touchedSectionIndex;
                  final next = (event.isInterestedForInteractions && index != null && index >= 0) ? index : null;
                  if (next != _hovered) setState(() => _hovered = next);
                },
              ),
              sections: [
                for (var i = 0; i < items.length; i++)
                  if (items[i].total > 0)
                    PieChartSectionData(
                      value: items[i].total.toDouble(),
                      color: orderStatusColor(items[i].status),
                      radius: _hovered == i ? 26 : 20,
                      showTitle: false,
                    ),
              ],
            ),
            duration: AppDurations.appear * 2,
            curve: AppCurves.enter,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${hovered?.total ?? total}',
                key: const ValueKey('total-ordenes'),
                style: theme.textTheme.headlineMedium,
              ),
              Text(hovered?.status.label ?? 'órdenes', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );

    final legend = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++)
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = items[i].total > 0 ? i : null),
            onExit: (_) => setState(() => _hovered = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: orderStatusColor(items[i].status), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      items[i].status.label,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: _hovered == i ? FontWeight.w600 : FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${items[i].total}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(items[i].total * 100 / total).round()}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 380;
        if (stacked) {
          return Column(children: [SizedBox(height: 170, child: donut), const SizedBox(height: AppSpacing.md), legend]);
        }
        return Row(
          children: [
            SizedBox(width: (constraints.maxHeight.isFinite ? constraints.maxHeight : 220).clamp(150.0, 230.0).toDouble(), child: donut),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

/// Barras delgadas de los ingresos pagados por mes. Eje con importes cortos, cuadrícula discreta y un tooltip con el
/// importe exacto al pasar el cursor.
class IncomeByMonthBars extends StatelessWidget {
  const IncomeByMonthBars({super.key, required this.data});

  final List<MonthlyIncome> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = data.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    if (max == 0) return const ChartEmpty('Sin cobros en los últimos 6 meses.');

    final interval = _niceInterval(max);
    final top = (max / interval).ceil() * interval;
    final last = data.length - 1;

    return BarChart(
      BarChartData(
        maxY: top.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.outline, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(_shortMoney(value), style: theme.textTheme.bodySmall),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _monthNames[(data[index].monthNumber - 1) % 12],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: index == last ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: index == last ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.sidebar,
            tooltipBorderRadius: BorderRadius.circular(AppRadius.control),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${_monthNames[(data[group.x].monthNumber - 1) % 12]}  ·  ${formatMoney(rod.toY.toStringAsFixed(2))}',
              theme.textTheme.bodySmall!.copyWith(color: AppColors.onSidebar, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].total,
                  width: 28,
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
      duration: AppDurations.appear * 2,
      curve: AppCurves.enter,
    );
  }

  /// Intervalo "redondo" del eje (1, 2, 2.5 o 5 por potencia de 10) para unas 4 o 5 divisiones.
  static double _niceInterval(double max) {
    final rough = max / 4;
    var magnitude = 1.0;
    while (magnitude * 10 <= rough) {
      magnitude *= 10;
    }
    while (magnitude > rough) {
      magnitude /= 10;
    }
    for (final step in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (step * magnitude >= rough) return step * magnitude;
    }
    return 10 * magnitude;
  }
}

/// Ingresos pagados por método: barras horizontales delgadas con el importe y el porcentaje al lado.
class IncomeByMethodBars extends StatelessWidget {
  const IncomeByMethodBars({super.key, required this.data});

  final List<MethodIncome> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.fold<double>(0, (sum, e) => sum + e.total);
    if (total == 0) return const ChartEmpty('Sin cobros en los últimos 6 meses.');
    final max = data.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final sorted = [...data]..sort((a, b) => b.total.compareTo(a.total));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final item in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(PaymentMethod.fromApi(item.method).label, style: theme.textTheme.bodyMedium)),
                    Text(
                      formatMoney(item.total.toStringAsFixed(2)),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('${(item.total * 100 / total).round()}%', textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: max == 0 ? 0 : item.total / max),
                    duration: AppDurations.appear * 2,
                    curve: AppCurves.enter,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
