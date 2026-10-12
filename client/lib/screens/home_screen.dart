import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/navigation_provider.dart';
import '../providers/session_provider.dart';
import '../providers/stock_alerts_provider.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/app_shell.dart' show iconForSection;
import '../widgets/stock_alerts_banner.dart';

/// Pantalla de inicio: bienvenida con el nombre, el rol y la fecha, y unos accesos rápidos según el rol. La
/// administración suma un acceso destacado al panel de control. No muestra indicadores ni estadísticas.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.now});

  /// Fecha y hora para el saludo. Solo se indica en pruebas; por omisión es el momento actual.
  final DateTime? now;

  static const Map<AppSection, String> _descriptions = {
    AppSection.clients: 'Registrar y consultar a los propietarios',
    AppSection.vehicles: 'Consultar los vehículos atendidos',
    AppSection.appointments: 'Programar y consultar la llegada de los vehículos',
    AppSection.orders: 'Crear y dar seguimiento a las órdenes de servicio',
    AppSection.myOrders: 'Consultar y trabajar las órdenes que tienes asignadas',
    AppSection.payments: 'Cobros de las órdenes y estado de Mercado Pago',
    AppSection.inventory: 'Existencias de refacciones y alertas de stock bajo',
  };

  /// Accesos rápidos de cada rol (pocos, los de uso diario; el resto está en el menú).
  static List<AppSection> _quickActionsFor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return [AppSection.orders, AppSection.appointments, AppSection.payments, AppSection.inventory];
      case UserRole.receptionist:
        return [AppSection.appointments, AppSection.orders, AppSection.clients, AppSection.payments];
      case UserRole.mechanic:
        return [AppSection.myOrders, AppSection.vehicles];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final moment = now ?? DateTime.now();
    final navigation = context.read<NavigationProvider>();
    final actions = _quickActionsFor(user.role);

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${greetingFor(moment)}, ${user.name}', key: const ValueKey('saludo'), style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('${user.role.label} · ${formatLongDate(moment)}', style: theme.textTheme.bodySmall),
              if (user.role == UserRole.admin) ...[
                const SizedBox(height: AppSpacing.xl),
                _FeaturedDashboardLink(onTap: () => navigation.goTo(AppSection.dashboard)),
                const _StockAlertNotice(),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Accesos rápidos', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final section in actions)
                    _QuickTile(
                      key: ValueKey('atajo-${section.name}'),
                      icon: iconForSection(section),
                      title: section.title,
                      description: _descriptions[section] ?? '',
                      onTap: () => navigation.goTo(section),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso destacado al panel de control, solo para la administración.
class _FeaturedDashboardLink extends StatelessWidget {
  const _FeaturedDashboardLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('acceso-panel-control'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.control)),
                child: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Panel de control', style: theme.textTheme.titleMedium),
                    Text('Indicadores, gráficas y actividad reciente del taller', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso rápido a una sección: ícono, nombre y una línea que explica para qué sirve.
class _QuickTile extends StatelessWidget {
  const _QuickTile({super.key, required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 236,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de stock bajo para la administración: aparece solo si hay refacciones en alerta y lleva a Inventario.
class _StockAlertNotice extends StatelessWidget {
  const _StockAlertNotice();

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<StockAlertsProvider>();
    if (!alerts.loaded || alerts.count == 0) return const SizedBox.shrink();
    final color = alerts.outOfStock > 0 ? AppColors.danger : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        key: const ValueKey('aviso-stock-bajo'),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        onTap: () => context.read<NavigationProvider>().goTo(AppSection.inventory),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: color, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(stockAlertsSummary(alerts.count, alerts.outOfStock))),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
