import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/navigation_provider.dart';
import '../providers/session_provider.dart';
import '../providers/sidebar_provider.dart';
import '../providers/stock_alerts_provider.dart';
import '../utils/tokens.dart';
import 'confirm_dialog.dart';

/// Construye la pantalla de una sección del menú.
typedef SectionBuilder = Widget Function(BuildContext context, AppSection section);

/// Ícono del menú de cada sección (contorno). También lo usa la pantalla de Inicio.
IconData iconForSection(AppSection section) {
  switch (section) {
    case AppSection.home:
      return Icons.home_outlined;
    case AppSection.clients:
      return Icons.people_outline;
    case AppSection.vehicles:
      return Icons.directions_car_outlined;
    case AppSection.appointments:
      return Icons.event_outlined;
    case AppSection.orders:
      return Icons.assignment_outlined;
    case AppSection.myOrders:
      return Icons.build_outlined;
    case AppSection.maintenance:
      return Icons.event_repeat_outlined;
    case AppSection.inventory:
      return Icons.inventory_2_outlined;
    case AppSection.dashboard:
      return Icons.dashboard_outlined;
    case AppSection.payments:
      return Icons.payments_outlined;
    case AppSection.tickets:
      return Icons.receipt_long_outlined;
    case AppSection.users:
      return Icons.admin_panel_settings_outlined;
    case AppSection.changePassword:
      return Icons.lock_outline;
  }
}

IconData _selectedIconFor(AppSection section) {
  switch (section) {
    case AppSection.home:
      return Icons.home;
    case AppSection.clients:
      return Icons.people;
    case AppSection.vehicles:
      return Icons.directions_car;
    case AppSection.appointments:
      return Icons.event;
    case AppSection.orders:
      return Icons.assignment;
    case AppSection.myOrders:
      return Icons.build;
    case AppSection.maintenance:
      return Icons.event_repeat;
    case AppSection.inventory:
      return Icons.inventory_2;
    case AppSection.dashboard:
      return Icons.dashboard;
    case AppSection.payments:
      return Icons.payments;
    case AppSection.tickets:
      return Icons.receipt_long;
    case AppSection.users:
      return Icons.admin_panel_settings;
    case AppSection.changePassword:
      return Icons.lock;
  }
}

/// Añade al ícono de Inventario una insignia con el número de refacciones en alerta (solo administración).
Widget _withBadge(BuildContext context, AppSection section, Widget icon) {
  if (section != AppSection.inventory) return icon;
  final count = context.watch<StockAlertsProvider>().count;
  if (count == 0) return icon;
  return Badge(key: const ValueKey('insignia-alertas'), label: Text('$count'), child: icon);
}

/// Estructura general: sidebar oscuro colapsable, encabezado y contenido con navegación propia.
/// Los permisos se validan en el servidor; aquí solo se muestran las opciones del rol.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.sectionBuilder});

  final SectionBuilder sectionBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<NavigatorState> _contentNavigator = GlobalKey<NavigatorState>();
  late AppSection _shown;

  @override
  void initState() {
    super.initState();
    _shown = context.read<NavigationProvider>().current;
    // Solo la administración consulta las alertas de stock bajo (el servidor rechaza a los demás roles).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alerts = context.read<StockAlertsProvider>();
      if (context.read<SessionProvider>().user?.role == UserRole.admin) {
        alerts.refresh();
      } else {
        alerts.clear();
      }
    });
  }

  Route<void> _routeFor(AppSection section) {
    // Respeta la preferencia del sistema de reducir el movimiento (docs/design-system.md §10).
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.navigation;
    return PageRouteBuilder<void>(
        settings: RouteSettings(name: section.name),
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (context, animation, secondaryAnimation) => widget.sectionBuilder(context, section),
        // La pantalla anterior se desvanece en la primera mitad y la nueva aparece en la segunda,
        // para que los títulos de ambas nunca se vean superpuestos.
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
          opacity: ReverseAnimation(CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.5))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: const Interval(0.5, 1, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar sesión?',
    );
    if (confirmed && mounted) {
      context.read<NavigationProvider>().reset();
      context.read<SessionProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final user = context.watch<SessionProvider>().user;
    if (user == null) return const SizedBox.shrink();

    // Al cambiar de sección se reinicia la pila de pantallas del contenido.
    if (navigation.current != _shown) {
      _shown = navigation.current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentNavigator.currentState?.pushAndRemoveUntil(_routeFor(_shown), (route) => false);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = context.watch<SidebarProvider>().isExpanded(constraints.maxWidth);
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                user: user,
                expanded: expanded,
                windowWidth: constraints.maxWidth,
                onLogout: _confirmLogout,
              ),
              Expanded(
                child: Column(
                  children: [
                    _Header(user: user, title: navigation.current.title),
                    const Divider(),
                    Expanded(
                      child: Navigator(
                        key: _contentNavigator,
                        onGenerateInitialRoutes: (navigator, initialRoute) => [_routeFor(_shown)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.expanded,
    required this.windowWidth,
    required this.onLogout,
  });

  final AppUser user;
  final bool expanded;
  final double windowWidth;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final sections = NavigationProvider.sectionsFor(user.role);
    final selected = sections.indexOf(navigation.current);

    final rail = NavigationRail(
          extended: expanded,
          minExtendedWidth: AppLayout.sidebarExpanded,
          minWidth: AppLayout.sidebarCollapsed,
          selectedIndex: selected < 0 ? null : selected,
          onDestinationSelected: (index) => navigation.goTo(sections[index]),
          labelType: NavigationRailLabelType.none,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: expanded ? 'Contraer menú' : 'Expandir menú',
                  child: IconButton(
                    onPressed: () => context.read<SidebarProvider>().toggle(windowWidth),
                    icon: Icon(expanded ? Icons.menu_open : Icons.menu, color: AppColors.onSidebar),
                  ),
                ),
                _RailLabel(
                  'Motorix',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onSidebar),
                ),
              ],
            ),
          ),
          destinations: [
            for (final section in sections)
              NavigationRailDestination(
                icon: Tooltip(message: section.title, child: _withBadge(context, section, Icon(iconForSection(section)))),
                selectedIcon: _withBadge(context, section, Icon(_selectedIconFor(section))),
                label: Text(section.title),
              ),
          ],
        );

    // El propio NavigationRail anima su ancho (~200 ms) al cambiar `extended`. Con ventanas bajas y muchas secciones
    // (administración) el menú se desplaza en lugar de desbordarse.
    // "Cerrar sesión" queda fijo al fondo, fuera del área que se desplaza.
    return ColoredBox(
      color: AppColors.sidebar,
      child: ClipRect(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(child: IntrinsicHeight(child: rail)),
            ),
            AnimatedContainer(
              duration: AppDurations.sidebar,
              curve: AppCurves.standard,
              width: expanded ? AppLayout.sidebarExpanded : AppLayout.sidebarCollapsed,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Tooltip(
                message: expanded ? '' : 'Cerrar sesión',
                child: TextButton(
                  onPressed: onLogout,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout, color: AppColors.onSidebarMuted),
                      if (expanded)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: Text(
                              'Cerrar sesión',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppColors.onSidebarMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto que aparece de forma gradual al expandir el sidebar (sigue la animación del propio
/// NavigationRail), de modo que ocupa ancho solo a medida que hay espacio y no desborda.
class _RailLabel extends StatelessWidget {
  const _RailLabel(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final animation = NavigationRail.extendedAnimation(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: animation.value,
          child: Opacity(opacity: animation.value, child: child),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.title});

  final AppUser user;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name, style: theme.textTheme.bodyLarge),
              Text(user.role.label, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<String>(
            tooltip: 'Opciones de la cuenta',
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
            onSelected: (value) {
              if (value == 'password') {
                context.read<NavigationProvider>().goTo(AppSection.changePassword);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'password', child: Text('Cambiar contraseña')),
            ],
          ),
        ],
      ),
    );
  }
}
