import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../providers/stock_alerts_provider.dart';
import '../utils/tokens.dart';
import '../widgets/stock_alerts_banner.dart';

/// Pantalla de bienvenida: nombre, rol y accesos directos a las secciones permitidas.
/// No muestra indicadores ni estadísticas (el panel de control es de otro sprint).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Map<AppSection, String> _descriptions = {
    AppSection.dashboard: 'Ver los indicadores y la actividad reciente del taller',
    AppSection.clients: 'Registrar y consultar a los propietarios',
    AppSection.vehicles: 'Registrar y consultar los vehículos atendidos',
    AppSection.appointments: 'Programar y consultar la llegada de los vehículos',
    AppSection.orders: 'Crear y dar seguimiento a las órdenes de servicio',
    AppSection.myOrders: 'Consultar y trabajar las órdenes que tienes asignadas',
    AppSection.payments: 'Consultar los cobros de las órdenes y el estado de Mercado Pago',
    AppSection.tickets: 'Consultar e imprimir los comprobantes de las órdenes cobradas',
    AppSection.maintenance: 'Ver los mantenimientos próximos y vencidos para avisar al cliente',
    AppSection.inventory: 'Controlar las refacciones, su existencia y las alertas de stock bajo',
    AppSection.users: 'Administrar quién puede usar el sistema',
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shortcuts = NavigationProvider.sectionsFor(user.role).where((s) => s != AppSection.home).toList();

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, ${user.name}', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('Sesión iniciada como ${user.role.label}', style: theme.textTheme.bodySmall),
              if (user.role == UserRole.admin) _StockAlertNotice(),
              const SizedBox(height: AppSpacing.xl),
              Text('Accesos directos', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Material(
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  side: const BorderSide(color: AppColors.outline),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < shortcuts.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        key: ValueKey('atajo-${shortcuts[i].name}'),
                        title: Text(shortcuts[i].title),
                        subtitle: Text(_descriptions[shortcuts[i]] ?? ''),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        onTap: () => context.read<NavigationProvider>().goTo(shortcuts[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de stock bajo en el inicio del administrador: aparece solo si hay refacciones en alerta y lleva a Inventario.
class _StockAlertNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<StockAlertsProvider>();
    if (!alerts.loaded || alerts.count == 0) return const SizedBox.shrink();
    final color = alerts.outOfStock > 0 ? AppColors.danger : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
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
