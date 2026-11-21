import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notice.dart';
import '../providers/navigation_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/session_provider.dart';
import '../utils/tokens.dart';
import 'state_views.dart';

const double _panelWidth = 420;

/// Abre el panel de notificaciones anclado a la esquina superior derecha, bajo el encabezado.
Future<void> showNotificationsPanel(BuildContext context) {
  final provider = context.read<NotificationsProvider>();
  // Al abrir el panel se actualizan los avisos para no mostrar datos viejos.
  provider.refresh();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar notificaciones',
    barrierColor: Colors.black26,
    transitionDuration: AppDurations.appear,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return ChangeNotifierProvider<NotificationsProvider>.value(
        value: provider,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl * 2, right: AppSpacing.xl),
            child: const NotificationsPanel(),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: animation, curve: AppCurves.enter), child: child),
  );
}

/// Contenido del panel: avisos agrupados por tipo, con los estados de carga, vacío y error.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;

    return Material(
      key: const ValueKey('panel-notificaciones'),
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _panelWidth, maxHeight: height * 0.75, minWidth: _panelWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notificaciones', style: theme.textTheme.titleMedium),
                        Text(
                          provider.unread == 1 ? '1 sin leer' : '${provider.unread} sin leer',
                          key: const ValueKey('sin-leer'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('cerrar-panel'),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _Body(provider: provider)),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    // Primera carga: indicador. Después se conserva el contenido anterior mientras se actualiza.
    if (!provider.loaded && provider.loading) {
      return const SizedBox(height: 160, child: LoadingView(label: 'Consultando avisos…'));
    }
    if (!provider.loaded && provider.error != null) {
      return SizedBox(
        height: 200,
        child: ErrorView(message: 'No se pudieron consultar los avisos.', onRetry: provider.refresh),
      );
    }
    final groups = provider.summary.groups;
    if (groups.isEmpty) return const _EmptyState();

    // Son como mucho 6 secciones de 50 avisos, así que no hace falta construir la lista de forma diferida.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) _InlineError(onRetry: provider.refresh),
          for (final group in groups) _GroupSection(group: group),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('sin-avisos'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text('No hay avisos pendientes', style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cuando haya algo que atender aparecerá aquí',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('error-avisos'),
      color: AppColors.danger.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('No se pudieron consultar los avisos')),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group});

  final NoticeGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey('grupo-${group.type.apiValue}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: group.type.tone.color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(group.type.sectionTitle, style: theme.textTheme.titleSmall)),
              Text('${group.total}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        for (final notice in group.items)
          NoticeTile(
            notice: notice,
            onTap: () => _openNotice(context, notice),
            onMarkRead: notice.read ? null : () => _markRead(context, notice),
          ),
        if (group.isTruncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text(
              'Mostrando ${group.items.length} de ${group.total}',
              key: ValueKey('limite-${group.type.apiValue}'),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Marca el aviso como leído y, si falla, lo dice con un mensaje y deja el aviso como estaba.
Future<void> _markRead(BuildContext context, AppNotice notice) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final error = await context.read<NotificationsProvider>().markRead([notice.key]);
  if (error != null) messenger?.showSnackBar(SnackBar(content: Text(error)));
}

/// Pulsar un aviso lo marca como leído, cierra el panel y abre la pantalla relacionada (orden, cita, vehículo
/// o inventario). Si marcarlo falla, el panel se cierra igual y se avisa con un mensaje.
Future<void> _openNotice(BuildContext context, AppNotice notice) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigation = context.read<NavigationProvider>();
  final provider = context.read<NotificationsProvider>();
  final role = context.read<SessionProvider>().user?.role;
  Navigator.of(context).pop();
  if (role != null) navigation.openTarget(notice.target, role);
  final error = await provider.markRead([notice.key]);
  if (error != null) messenger?.showSnackBar(SnackBar(content: Text(error)));
}

/// Un aviso del panel. Los no leídos llevan un punto y texto normal; los leídos se atenúan.
class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice, this.onTap, this.onMarkRead});

  final AppNotice notice;
  final VoidCallback? onTap;

  /// Acción «Marcar como leído» (solo si el aviso está sin leer).
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = notice.read;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
      color: muted ? AppColors.textSecondary : AppColors.textPrimary,
    );
    return InkWell(
      key: ValueKey('aviso-${notice.key}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 14,
              child: notice.read
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, key: ValueKey('no-leido-${notice.key}'), size: 8, color: notice.type.tone.color),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(notice.detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (onMarkRead != null)
              TextButton(
                key: ValueKey('marcar-leido-${notice.key}'),
                onPressed: onMarkRead,
                child: const Text('Marcar como leído'),
              ),
          ],
        ),
      ),
    );
  }
}
