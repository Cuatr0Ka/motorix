/// Roles de acceso. El servidor es quien valida los permisos; el cliente solo decide qué mostrar.
enum UserRole {
  admin('ADMIN', 'Administrador'),
  receptionist('RECEPTIONIST', 'Recepcionista'),
  mechanic('MECHANIC', 'Mecánico');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(String? value) =>
      UserRole.values.firstWhere((r) => r.apiValue == value, orElse: () => UserRole.mechanic);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        username: '${json['username']}',
        name: '${json['name']}',
        email: '${json['email']}',
        role: UserRole.fromApi(json['role'] as String?),
        active: json['active'] as bool? ?? true,
      );

  final int id;
  final String username;
  final String name;
  final String email;
  final UserRole role;
  final bool active;

  /// Crear y editar clientes y vehículos (ADMIN y RECEPTIONIST).
  bool get canEditRecords => role == UserRole.admin || role == UserRole.receptionist;

  /// Gestionar usuarios (solo ADMIN).
  bool get canManageUsers => role == UserRole.admin;
}
