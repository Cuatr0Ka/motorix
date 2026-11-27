import 'package:flutter/foundation.dart';

import '../models/notice.dart';
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
  clientNotices('Clientes por avisar'),
  inventory('Inventario'),
  users('Usuarios'),
  settings('Configuración'),
  terms('Términos y privacidad'),
  reports('Reportes'),
  auditLog('Bitácora'),
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
          AppSection.clientNotices,
        ],
        if (role == UserRole.mechanic) AppSection.myOrders,
        if (role == UserRole.admin) AppSection.inventory,
      ];

  /// Secciones de administración: no van en el menú lateral sino en el menú de la cuenta (encabezado).
  static List<AppSection> adminSectionsFor(UserRole role) => [
        if (role == UserRole.admin) ...[
          AppSection.users,
          AppSection.reports,
          AppSection.settings,
          AppSection.terms,
          AppSection.auditLog,
        ],
      ];

  /// Pantalla de detalle pendiente de abrir (viene de un aviso). La toma el AppShell y la abre.
  NoticeTarget? _pendingTarget;

  NoticeTarget? get pendingTarget => _pendingTarget;

  void goTo(AppSection section) {
    if (section == _current) return;
    _current = section;
    notifyListeners();
  }

  /// Sección del menú a la que pertenece el destino de un aviso (el mecánico ve sus órdenes en «Mis órdenes»).
  static AppSection sectionForTarget(String kind, UserRole role) {
    switch (kind) {
      case 'order':
        return role == UserRole.mechanic ? AppSection.myOrders : AppSection.orders;
      case 'appointment':
        return AppSection.appointments;
      case 'vehicle':
        return AppSection.vehicles;
      default:
        return AppSection.inventory;
    }
  }

  /// Abre el módulo relacionado con un aviso: cambia a su sección y deja el detalle pendiente de abrir.
  void openTarget(NoticeTarget target, UserRole role) {
    _pendingTarget = target;
    final section = sectionForTarget(target.kind, role);
    if (section == _current) {
      notifyListeners();
    } else {
      goTo(section);
    }
  }

  /// Entrega el destino pendiente una sola vez.
  NoticeTarget? takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  void reset() {
    _current = AppSection.home;
    notifyListeners();
  }
}
