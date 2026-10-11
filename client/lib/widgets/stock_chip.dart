import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import 'status_chip.dart';

/// Chip del estado de stock: Suficiente (verde), Bajo (ámbar) o Agotado (rojo); una refacción
/// inactiva se muestra en tono neutro. Siempre lleva texto además del color.
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.status, this.active = true});

  final StockStatus status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return const StatusChip(label: 'Inactiva', tone: StatusTone.neutral);
    return StatusChip(label: status.label, tone: status.tone);
  }
}
