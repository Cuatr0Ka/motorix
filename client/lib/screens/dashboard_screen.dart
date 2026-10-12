import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/kpi_card.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Panel de control del taller (solo administración) y pantalla principal de la administración: indicadores
/// principales, gráficas (órdenes por estado e ingresos), resumen operativo y actividad reciente, a todo el ancho.
/// Todo se calcula en el servidor con datos reales; cada indicador lleva al listado correspondiente.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  void _go(AppSection section) => context.read<NavigationProvider>().goTo(section);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final dashboard = provider.dashboard;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Panel de control',
            subtitle: dashboard == null ? 'Información general del taller' : 'Actualizado ${formatDateTime(dashboard.generatedAt)}',
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('actualizar-panel'),
                onPressed: provider.loading ? null : provider.load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(provider.loading ? 'Actualizando…' : 'Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (provider.error != null && dashboard != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(provider.error!, key: const ValueKey('error-actualizar-panel'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          Expanded(
            child: dashboard == null
                ? (provider.error != null
                    ? ErrorView(message: provider.error!, onRetry: provider.load)
                    : const LoadingView(label: 'Cargando el panel…'))
                : SingleChildScrollView(child: _Content(dashboard: dashboard, onGo: _go)),
          ),
        ],
      ),
    );
  }
}

/// Distribución adaptable: cuatro columnas en pantallas anchas, dos en medianas y una en angostas.
class _Content extends StatelessWidget {
  const _Content({required this.dashboard, required this.onGo});

  final Dashboard dashboard;
  final ValueChanged<AppSection> onGo;

  static const double _gap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 1100;
        final medium = width >= 700;

        final kpis = [
          KpiCard(
            label: 'Vehículos en reparación',
            value: dashboard.inRepair,
            icon: Icons.build_outlined,
            hint: 'De ${dashboard.pendingOrders} órdenes pendientes',
            onTap: () => onGo(AppSection.orders),
          ),
          KpiCard(
            label: 'Citas próximas',
            value: dashboard.upcomingAppointments,
            icon: Icons.event_outlined,
            hint: 'Próximos 7 días',
            onTap: () => onGo(AppSection.appointments),
          ),
          KpiCard(
            label: 'Mantenimientos vencidos',
            value: dashboard.overdueMaintenance,
            icon: Icons.event_repeat_outlined,
            tone: StatusTone.danger,
            hint: 'Avisar al cliente',
            onTap: () => onGo(AppSection.maintenance),
          ),
          KpiCard(
            label: 'Refacciones con stock bajo',
            value: dashboard.lowStock,
            icon: Icons.inventory_2_outlined,
            tone: StatusTone.warning,
            hint: 'Incluye las agotadas',
            onTap: () => onGo(AppSection.inventory),
          ),
        ];

        final donut = _Panel(
          title: 'Órdenes por estado',
          subtitle: 'Todas las órdenes del taller',
          height: 280,
          child: OrdersByStatusDonut(data: dashboard.ordersByStatus),
        );
        final monthly = _Panel(
          title: 'Ingresos por mes',
          subtitle: 'Pagos cobrados, últimos 6 meses',
          height: 280,
          child: IncomeByMonthBars(data: dashboard.incomeByMonth),
        );
        final byMethod = _Panel(
          title: 'Ingresos por método de pago',
          subtitle: 'Últimos 6 meses',
          height: 280,
          child: IncomeByMethodBars(data: dashboard.incomeByMethod),
        );

        final summary = _Panel(title: 'Resumen operativo', child: _Summary(dashboard: dashboard, onGo: onGo));
        final changes = _Panel(title: 'Cambios de orden', child: _OrderChanges(dashboard: dashboard));
        final payments = _Panel(title: 'Pagos recientes', child: _Payments(dashboard: dashboard));
        final movements = _Panel(title: 'Movimientos de inventario', child: _Movements(dashboard: dashboard));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grid(kpis, wide ? 4 : (medium ? 2 : 1)),
            const SizedBox(height: _gap),
            if (wide)
              _flexRow([(4, donut), (5, monthly), (3, byMethod)])
            else
              _grid([donut, monthly, byMethod], medium ? 2 : 1),
            const SizedBox(height: _gap),
            if (wide)
              IntrinsicHeight(child: _flexRow([(3, summary), (3, changes), (3, payments), (3, movements)], stretch: true))
            else
              _grid([summary, changes, payments, movements], medium ? 2 : 1),
          ],
        );
      },
    );
  }

  Widget _flexRow(List<(int, Widget)> items, {bool stretch = false}) => Row(
        crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(flex: items[i].$1, child: items[i].$2),
          ],
        ],
      );

  /// Reparte los elementos en filas de [columns] columnas iguales.
  Widget _grid(List<Widget> items, int columns) {
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += columns) {
      final chunk = items.skip(start).take(columns).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: start == 0 ? 0 : _gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: i < chunk.length ? chunk[i] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Panel con borde fino, título, subtítulo opcional y, si se indica, una altura fija para el contenido (gráficas).
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle, this.height});

  final String title;
  final String? subtitle;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (height != null) SizedBox(height: height, child: child) else child,
        ],
      ),
    );
  }
}

/// Indicadores secundarios en forma de lista: cada renglón lleva a su listado.
class _Summary extends StatelessWidget {
  const _Summary({required this.dashboard, required this.onGo});

  final Dashboard dashboard;
  final ValueChanged<AppSection> onGo;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _SummaryRow(label: 'Vehículos atendidos', hint: 'Últimos 30 días', value: dashboard.attendedLast30Days, onTap: () => onGo(AppSection.orders)),
      _SummaryRow(label: 'Órdenes pendientes', hint: 'Sin terminar', value: dashboard.pendingOrders, onTap: () => onGo(AppSection.orders)),
      _SummaryRow(label: 'Terminadas por entregar', value: dashboard.finishedAwaitingDelivery, onTap: () => onGo(AppSection.orders)),
      _SummaryRow(label: 'Órdenes terminadas por cobrar', value: dashboard.ordersAwaitingPayment, tone: StatusTone.warning, onTap: () => onGo(AppSection.payments)),
      _SummaryRow(label: 'Cobros de Mercado Pago pendientes', value: dashboard.pendingMercadoPago, tone: StatusTone.warning, onTap: () => onGo(AppSection.payments)),
      _SummaryRow(label: 'Mantenimientos próximos', value: dashboard.upcomingMaintenance, tone: StatusTone.warning, onTap: () => onGo(AppSection.maintenance)),
      _SummaryRow(label: 'Refacciones agotadas', value: dashboard.outOfStock, tone: StatusTone.danger, onTap: () => onGo(AppSection.inventory)),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(),
          rows[i],
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.onTap, this.hint, this.tone = StatusTone.neutral});

  final String label;
  final String? hint;
  final int value;
  final StatusTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = value == 0 ? AppColors.textSecondary : (tone == StatusTone.neutral ? AppColors.textPrimary : tone.color);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium),
                    if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('$value', key: ValueKey('valor-$label'), style: theme.textTheme.titleMedium?.copyWith(color: color)),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renglón de actividad: texto principal, línea de apoyo y un valor a la derecha.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.title, required this.caption, this.trailing});

  final String title;
  final String caption;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                Text(caption, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(trailing!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

Widget _list(BuildContext context, List<Widget> rows, String empty) {
  if (rows.isEmpty) return Text(empty, style: Theme.of(context).textTheme.bodySmall);
  return Column(children: [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const Divider(),
      rows[i],
    ],
  ]);
}

class _OrderChanges extends StatelessWidget {
  const _OrderChanges({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) => _list(
        context,
        [
          for (final change in dashboard.orderChanges)
            _ActivityRow(
              title: '${change.folio} → ${OrderStatus.fromApi(change.toStatus).label}',
              caption: '${change.changedBy} · ${formatDateTime(change.changedAt)}',
            ),
        ],
        'Sin cambios recientes.',
      );
}

class _Payments extends StatelessWidget {
  const _Payments({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) => _list(
        context,
        [
          for (final payment in dashboard.payments)
            _ActivityRow(
              title: '${payment.orderFolio} · ${PaymentStatus.fromApi(payment.status).label}',
              caption: '${PaymentMethod.fromApi(payment.method).label} · ${formatDateTime(payment.createdAt)}',
              trailing: formatMoney(payment.amount),
            ),
        ],
        'Sin pagos recientes.',
      );
}

class _Movements extends StatelessWidget {
  const _Movements({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) => _list(
        context,
        [
          for (final movement in dashboard.inventoryMovements)
            _ActivityRow(
              title: movement.partCode,
              caption: '${movement.type == 'IN' ? 'Entrada' : movement.type == 'OUT' ? 'Salida' : 'Ajuste'} · ${formatDateTime(movement.createdAt)}',
              trailing: movement.quantity > 0 ? '+${movement.quantity}' : '−${movement.quantity.abs()}',
            ),
        ],
        'Sin movimientos recientes.',
      );
}
