import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// Secciones del menú lateral.
enum AppSection {
  home('Inicio'),
  dashboard('Panel de control'),
  clients('Clientes'),
  vehicles('Vehículos'),
  appointments('Citas'),
  orders('Órdenes'),
  myOrders('Mis órdenes'),
  payments('Pagos'),
  tickets('Tickets'),
  maintenance('Mantenimientos'),
  inventory('Inventario'),
  users('Usuarios'),
  changePassword('Cambiar contraseña');

  const AppSection(this.title);

  final String title;
}

/// Sección activa. Cambiarla reinicia la pila de pantallas del contenido.
class NavigationProvider extends ChangeNotifier {
  AppSection _current = AppSection.home;

  AppSection get current => _current;

  /// Secciones permitidas para el rol (ocultar no es seguridad: el servidor también valida).
  static List<AppSection> sectionsFor(UserRole role) => [
        AppSection.home,
        if (role == UserRole.admin) AppSection.dashboard,
        AppSection.clients,
        AppSection.vehicles,
        if (role == UserRole.admin || role == UserRole.receptionist) ...[
          AppSection.appointments,
          AppSection.orders,
          AppSection.payments,
          AppSection.tickets,
          AppSection.maintenance,
        ],
        if (role == UserRole.mechanic) AppSection.myOrders,
        if (role == UserRole.admin) AppSection.inventory,
        if (role == UserRole.admin) AppSection.users,
      ];

  void goTo(AppSection section) {
    if (section == _current) return;
    _current = section;
    notifyListeners();
  }

  void reset() {
    _current = AppSection.home;
    notifyListeners();
  }
}
