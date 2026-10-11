import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../providers/session_provider.dart';
import '../utils/tokens.dart';

/// Pantalla de bienvenida: nombre, rol y accesos directos a las secciones permitidas.
/// No muestra indicadores ni estadísticas (el panel de control es de otro sprint).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Map<AppSection, String> _descriptions = {
    AppSection.clients: 'Registrar y consultar a los propietarios',
    AppSection.vehicles: 'Registrar y consultar los vehículos atendidos',
    AppSection.appointments: 'Programar y consultar la llegada de los vehículos',
    AppSection.orders: 'Crear y dar seguimiento a las órdenes de servicio',
    AppSection.myOrders: 'Consultar y trabajar las órdenes que tienes asignadas',
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
