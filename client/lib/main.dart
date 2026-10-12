import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/appointments_provider.dart';
import 'providers/clients_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/parts_provider.dart';
import 'providers/payments_provider.dart';
import 'providers/session_provider.dart';
import 'providers/sidebar_provider.dart';
import 'providers/stock_alerts_provider.dart';
import 'providers/tickets_provider.dart';
import 'providers/users_provider.dart';
import 'providers/vehicles_provider.dart';
import 'screens/appointments_list_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/clients_list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_list_screen.dart';
import 'screens/payments_list_screen.dart';
import 'screens/tickets_list_screen.dart';
import 'screens/orders_list_screen.dart';
import 'screens/users_screen.dart';
import 'screens/vehicles_list_screen.dart';
import 'services/api_client.dart';
import 'services/appointments_service.dart';
import 'services/auth_service.dart';
import 'services/clients_service.dart';
import 'services/dashboard_service.dart';
import 'services/maintenance_service.dart';
import 'services/orders_service.dart';
import 'services/parts_service.dart';
import 'services/payments_service.dart';
import 'services/tickets_service.dart';
import 'services/users_service.dart';
import 'services/vehicles_service.dart';
import 'utils/app_theme.dart';
import 'utils/link_opener.dart';
import 'utils/ticket_printer.dart';
import 'utils/tokens.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(MotorixApp(apiClient: ApiClient()));
}

/// Raíz de la aplicación. Recibe el cliente HTTP para poder simularlo en las pruebas.
class MotorixApp extends StatelessWidget {
  const MotorixApp({
    super.key,
    required this.apiClient,
    this.useGoogleFonts = true,
    this.linkOpener = const SystemLinkOpener(),
    this.ticketPrinter = const SystemTicketPrinter(),
  });

  final ApiClient apiClient;

  /// Abre enlaces en el navegador (se sustituye en las pruebas).
  final LinkOpener linkOpener;

  /// Imprime tickets con el diálogo del sistema (se sustituye en las pruebas).
  final TicketPrinter ticketPrinter;
  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService(apiClient);
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => SessionProvider(apiClient, authService)),
        ChangeNotifierProvider(create: (_) => SidebarProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        Provider<ClientsService>(create: (_) => ClientsService(apiClient)),
        ChangeNotifierProvider(create: (context) => ClientsProvider(context.read<ClientsService>())),
        Provider<VehiclesService>(create: (_) => VehiclesService(apiClient)),
        ChangeNotifierProvider(create: (context) => VehiclesProvider(context.read<VehiclesService>())),
        Provider<AppointmentsService>(create: (_) => AppointmentsService(apiClient)),
        ChangeNotifierProvider(create: (context) => AppointmentsProvider(context.read<AppointmentsService>())),
        Provider<MaintenanceService>(create: (_) => MaintenanceService(apiClient)),
        ChangeNotifierProvider(create: (context) => MaintenanceProvider(context.read<MaintenanceService>())),
        Provider<OrdersService>(create: (_) => OrdersService(apiClient)),
        ChangeNotifierProvider(create: (context) => OrdersProvider(context.read<OrdersService>())),
        Provider<DashboardService>(create: (_) => DashboardService(apiClient)),
        ChangeNotifierProvider(create: (context) => DashboardProvider(context.read<DashboardService>())),
        Provider<LinkOpener>.value(value: linkOpener),
        Provider<TicketPrinter>.value(value: ticketPrinter),
        Provider<TicketsService>(create: (_) => TicketsService(apiClient)),
        ChangeNotifierProvider(create: (context) => TicketsProvider(context.read<TicketsService>())),
        Provider<PaymentsService>(create: (_) => PaymentsService(apiClient)),
        ChangeNotifierProvider(create: (context) => PaymentsProvider(context.read<PaymentsService>())),
        Provider<PartsService>(create: (_) => PartsService(apiClient)),
        ChangeNotifierProvider(create: (context) => PartsProvider(context.read<PartsService>())),
        ChangeNotifierProvider(create: (context) => StockAlertsProvider(context.read<PartsService>())),
        Provider<UsersService>(create: (_) => UsersService(apiClient)),
        ChangeNotifierProvider(create: (context) => UsersProvider(context.read<UsersService>())),
      ],
      child: MaterialApp(
        title: 'Motorix',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(useGoogleFonts: useGoogleFonts),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Muestra el acceso o la aplicación según la sesión, con un cambio suave entre ambos.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<SessionProvider, bool>((s) => s.isSignedIn);
    // Respeta la preferencia del sistema de reducir el movimiento.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : AppDurations.navigation,
      switchInCurve: AppCurves.enter,
      child: signedIn
          ? const AppShell(key: ValueKey('app'), sectionBuilder: buildSection)
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

/// Pantalla de cada sección del menú.
Widget buildSection(BuildContext context, AppSection section) {
  switch (section) {
    case AppSection.home:
      return const HomeScreen();
    case AppSection.dashboard:
      return const DashboardScreen();
    case AppSection.clients:
      return const ClientsListScreen();
    case AppSection.vehicles:
      return const VehiclesListScreen();
    case AppSection.appointments:
      return const AppointmentsListScreen();
    case AppSection.orders:
      return const OrdersListScreen();
    case AppSection.myOrders:
      return const OrdersListScreen(mine: true);
    case AppSection.payments:
      return const PaymentsListScreen();
    case AppSection.tickets:
      return const TicketsListScreen();
    case AppSection.maintenance:
      return const MaintenanceListScreen();
    case AppSection.inventory:
      return const InventoryScreen();
    case AppSection.users:
      return const UsersScreen();
    case AppSection.changePassword:
      return const ChangePasswordScreen();
  }
}
