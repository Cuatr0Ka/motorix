import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../utils/tokens.dart';
import 'notifications_panel.dart';

/// Texto de la insignia de la campana: sin número con 0 avisos y «99+» si pasa de 99.
String? bellBadgeText(int unread) {
  if (unread <= 0) return null;
  return unread > 99 ? '99+' : '$unread';
}

/// Campana del encabezado con el total de avisos no leídos. Abre el panel de notificaciones.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final unread = provider.unread;
    final text = bellBadgeText(unread);
    // El rojo se reserva para avisos críticos (vencidos o stock agotado) sin leer; lo demás es ámbar.
    final color = provider.hasCriticalUnread ? AppColors.danger : AppColors.warning;
    final label = unread > 0 ? 'Notificaciones, $unread sin leer' : 'Notificaciones, sin avisos pendientes';

    return Semantics(
      label: label,
      button: true,
      child: ExcludeSemantics(
        child: IconButton(
          key: const ValueKey('campana'),
          tooltip: 'Notificaciones',
          onPressed: () => showNotificationsPanel(context),
          icon: Badge(
            key: const ValueKey('insignia-campana'),
            isLabelVisible: text != null,
            label: text == null ? null : Text(text, key: const ValueKey('contador-campana')),
            backgroundColor: color,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
