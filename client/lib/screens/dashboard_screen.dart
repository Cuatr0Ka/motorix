import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/indicator_card.dart';
import '../widgets/page_header.dart';
import '../widgets/panel_card.dart';
import '../widgets/state_views.dart';

/// Panel de control del taller (solo administración): indicadores reales de órdenes, citas, mantenimientos, inventario
/// y cobros, y la actividad reciente. Cada tarjeta lleva al listado correspondiente.
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
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Group(title: 'Órdenes', cards: [
                          IndicatorCard(label: 'Vehículos atendidos', hint: 'Últimos 30 días', value: dashboard.attendedLast30Days, onTap: () => _go(AppSection.orders)),
                          IndicatorCard(label: 'Vehículos en reparación', value: dashboard.inRepair, onTap: () => _go(AppSection.orders)),
                          IndicatorCard(label: 'Órdenes pendientes', hint: 'Sin terminar', value: dashboard.pendingOrders, onTap: () => _go(AppSection.orders)),
                          IndicatorCard(label: 'Terminadas por entregar', value: dashboard.finishedAwaitingDelivery, onTap: () => _go(AppSection.orders)),
                        ]),
                        _Group(title: 'Citas', cards: [
                          IndicatorCard(label: 'Citas próximas', hint: 'Próximos 7 días', value: dashboard.upcomingAppointments, onTap: () => _go(AppSection.appointments)),
                        ]),
                        _Group(title: 'Mantenimientos', cards: [
                          IndicatorCard(label: 'Mantenimientos próximos', value: dashboard.upcomingMaintenance, tone: StatusTone.warning, onTap: () => _go(AppSection.maintenance)),
                          IndicatorCard(label: 'Mantenimientos vencidos', value: dashboard.overdueMaintenance, tone: StatusTone.danger, onTap: () => _go(AppSection.maintenance)),
                        ]),
                        _Group(title: 'Inventario', cards: [
                          IndicatorCard(label: 'Refacciones con stock bajo', hint: 'Incluye las agotadas', value: dashboard.lowStock, tone: StatusTone.warning, onTap: () => _go(AppSection.inventory)),
                          IndicatorCard(label: 'Refacciones agotadas', value: dashboard.outOfStock, tone: StatusTone.danger, onTap: () => _go(AppSection.inventory)),
                        ]),
                        _Group(title: 'Cobros', cards: [
                          IndicatorCard(label: 'Órdenes terminadas por cobrar', value: dashboard.ordersAwaitingPayment, tone: StatusTone.warning, onTap: () => _go(AppSection.payments)),
                          IndicatorCard(label: 'Cobros de Mercado Pago pendientes', value: dashboard.pendingMercadoPago, tone: StatusTone.warning, onTap: () => _go(AppSection.payments)),
                        ]),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Actividad reciente', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.md),
                        _RecentActivity(dashboard: dashboard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.cards});

  final String title;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: cards),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget empty(String text) => Text(text, style: theme.textTheme.bodySmall);
    Widget row(String left, String right) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(left, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.sm),
              Text(right, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        SizedBox(
          width: 360,
          child: PanelCard(
            title: 'Cambios de orden',
            child: dashboard.orderChanges.isEmpty
                ? empty('Sin cambios recientes.')
                : Column(children: [
                    for (final change in dashboard.orderChanges)
                      row('${change.folio} → ${OrderStatus.fromApi(change.toStatus).label} · ${change.changedBy}', formatDateTime(change.changedAt)),
                  ]),
          ),
        ),
        SizedBox(
          width: 360,
          child: PanelCard(
            title: 'Pagos',
            child: dashboard.payments.isEmpty
                ? empty('Sin pagos recientes.')
                : Column(children: [
                    for (final payment in dashboard.payments)
                      row(
                        '${payment.orderFolio} · ${PaymentMethod.fromApi(payment.method).label} · ${PaymentStatus.fromApi(payment.status).label}',
                        formatMoney(payment.amount),
                      ),
                  ]),
          ),
        ),
        SizedBox(
          width: 360,
          child: PanelCard(
            title: 'Movimientos de inventario',
            child: dashboard.inventoryMovements.isEmpty
                ? empty('Sin movimientos recientes.')
                : Column(children: [
                    for (final movement in dashboard.inventoryMovements)
                      row(
                        '${movement.partCode} · ${movement.type == 'IN' ? 'Entrada' : movement.type == 'OUT' ? 'Salida' : 'Ajuste'}',
                        movement.quantity > 0 ? '+${movement.quantity}' : '−${movement.quantity.abs()}',
                      ),
                  ]),
          ),
        ),
      ],
    );
  }
}
