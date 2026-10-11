import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import 'status_chip.dart';

/// Chip del indicador de un mantenimiento: Normal (verde), Próximo (ámbar) o Vencido (rojo); un
/// mantenimiento atendido se muestra en tono neutro. Siempre lleva texto además del color.
class MaintenanceChip extends StatelessWidget {
  const MaintenanceChip({super.key, this.indicator, this.attended = false});

  final MaintenanceIndicator? indicator;
  final bool attended;

  @override
  Widget build(BuildContext context) {
    if (attended || indicator == null) {
      return const StatusChip(label: 'Atendido', tone: StatusTone.neutral);
    }
    return StatusChip(label: indicator!.label, tone: indicator!.tone);
  }
}
