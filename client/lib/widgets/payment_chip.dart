import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import 'status_chip.dart';

/// Chip del estado de un pago: Pagado (verde), Pendiente (ámbar), Rechazado (rojo) o Cancelado (neutro).
class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(label: status.label, tone: status.tone);
}

/// Chip del estado de cobro de una orden: Sin cobrar, Cobro pendiente o Pagado.
class CollectionChip extends StatelessWidget {
  const CollectionChip({super.key, required this.status});

  final CollectionStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(label: status.label, tone: status.tone);
}
