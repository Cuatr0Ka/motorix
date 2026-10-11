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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: tone.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone.color, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
