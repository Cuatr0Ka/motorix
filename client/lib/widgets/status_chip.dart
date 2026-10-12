import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import '../utils/tokens.dart';

/// Chip de estado con el color de su tono (verde completado, ámbar espera, rojo cancelado…).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  StatusChip.appointment(AppointmentStatus status, {Key? key}) : this(key: key, label: status.label, tone: status.tone);

  StatusChip.order(OrderStatus status, {Key? key}) : this(key: key, label: status.label, tone: status.tone);

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    // Texto más oscuro que el borde y relleno algo más intenso para que se lea bien sobre blanco.
    final textColor = Color.lerp(tone.color, Colors.black, 0.3)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: tone.color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
