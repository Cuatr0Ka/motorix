import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/navigation_provider.dart';
import '../providers/session_provider.dart';
import '../providers/users_provider.dart';
import '../services/api_client.dart';
import '../services/users_service.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'user_form_screen.dart';

/// Gestión de usuarios y roles (solo administrador).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UsersProvider>().load(search: '', page: 1);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => const UserFormScreen()),
    );
    if (created != null && mounted) {
      await context.read<UsersProvider>().reload();
      if (mounted) showSuccess(context, 'Usuario creado correctamente.');
    }
  }

  /// Si la persona modificó su propia cuenta se actualiza su perfil y, si ya no es admin, se regresa al inicio.
  Future<void> _afterChange(AppUser changed) async {
    final session = context.read<SessionProvider>();
    await context.read<UsersProvider>().reload();
    if (changed.id == session.user?.id) {
      await session.refreshProfile();
      if (mounted && !(session.user?.canManageUsers ?? false)) {
        context.read<NavigationProvider>().reset();
      }
    }
  }

  Future<void> _changeRole(AppUser user) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (_) => _RoleDialog(user: user),
    );
    if (role == null || role == user.role || !mounted) return;
    try {
      final updated = await context.read<UsersService>().changeRole(user.id, role);
      if (!mounted) return;
      showSuccess(context, 'Rol actualizado. Rige desde su siguiente acción.');
      await _afterChange(updated);
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    }
  }

  Future<void> _toggleActive(AppUser user) async {
    // Desactivar es una acción sensible: pide confirmación. Reactivar no.
    if (user.active) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Desactivar usuario',
        message: '¿Seguro que quieres desactivar a ${user.name}? No podrá iniciar sesión hasta que lo actives de nuevo.',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      final updated = await context.read<UsersService>().setActive(user.id, !user.active);
      if (!mounted) return;
      showSuccess(context, user.active ? 'Usuario desactivado.' : 'Usuario activado.');
      await _afterChange(updated);
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsersProvider>();
    final currentId = context.watch<SessionProvider>().user?.id;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Usuarios',
            subtitle: 'Quién puede usar el sistema y con qué rol',
            actions: [
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo usuario'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DebouncedSearchField(
              hint: 'Buscar por usuario, nombre o correo',
              initialValue: provider.search,
              onChanged: (value) => context.read<UsersProvider>().load(search: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _Body(
              provider: provider,
              currentUserId: currentId,
              onCreate: _create,
              onChangeRole: _changeRole,
              onToggleActive: _toggleActive,
            ),
          ),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<UsersProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.provider,
    required this.currentUserId,
    required this.onCreate,
    required this.onChangeRole,
    required this.onToggleActive,
  });

  final UsersProvider provider;
  final int? currentUserId;
  final VoidCallback onCreate;
  final ValueChanged<AppUser> onChangeRole;
  final ValueChanged<AppUser> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null || provider.status == LoadStatus.error) {
      if (provider.status == LoadStatus.error) {
        return ErrorView(message: provider.error ?? 'No se pudo cargar.', onRetry: provider.reload);
      }
      return const LoadingView();
    }
    if (result.items.isEmpty) {
      if (provider.status == LoadStatus.loading) return const LoadingView();
      return provider.hasSearch
          ? const EmptyView(message: 'No se encontraron usuarios con esa búsqueda.')
          : EmptyView(
              message: 'Todavía no hay usuarios registrados.',
              actionLabel: 'Crear el primer usuario',
              onAction: onCreate,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 820,
        columns: const [
          DataColumn2(label: Text('Usuario'), size: ColumnSize.M),
          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
          DataColumn2(label: Text('Correo'), size: ColumnSize.L),
          DataColumn2(label: Text('Rol'), size: ColumnSize.M),
          DataColumn2(label: Text('Estado'), fixedWidth: 110),
          DataColumn2(label: Text('Acciones'), fixedWidth: 80),
        ],
        rows: [
          for (final user in result.items)
            DataRow2(
              key: ValueKey('usuario-${user.id}'),
              cells: [
                DataCell(Text(user.username + (user.id == currentUserId ? ' (tú)' : ''))),
                DataCell(Text(user.name, overflow: TextOverflow.ellipsis)),
                DataCell(Text(user.email, overflow: TextOverflow.ellipsis)),
                DataCell(Text(user.role.label)),
                DataCell(_StatusChip(active: user.active)),
                DataCell(
                  PopupMenuButton<String>(
                    tooltip: 'Acciones de ${user.username}',
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) => value == 'role' ? onChangeRole(user) : onToggleActive(user),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'role', child: Text('Cambiar rol')),
                      PopupMenuItem(value: 'active', child: Text(user.active ? 'Desactivar' : 'Activar')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Chip(
      label: Text(active ? 'Activo' : 'Inactivo'),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w500),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.user});

  final AppUser user;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late UserRole _role = widget.user.role;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cambiar rol de ${widget.user.name}'),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<UserRole>(
          key: const ValueKey('selector-rol'),
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: [
            for (final role in UserRole.values) DropdownMenuItem(value: role, child: Text(role.label)),
          ],
          onChanged: (value) => setState(() => _role = value ?? _role),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_role), child: const Text('Guardar')),
      ],
    );
  }
}
