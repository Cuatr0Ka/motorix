import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tono visual de un estado (convención de color de `docs/design-system.md`).
enum StatusTone {
  neutral(AppColors.textSecondary),
  active(AppColors.primary),
  warning(AppColors.warning),
  success(AppColors.success),
  danger(AppColors.danger);

  const StatusTone(this.color);

  final Color color;
}

/// Estados de una cita. `apiValue` es el valor que viaja en la API.
enum AppointmentStatus {
  pending('PENDIENTE', 'Pendiente', StatusTone.neutral),
  confirmed('CONFIRMADA', 'Confirmada', StatusTone.active),
  inProgress('EN_PROCESO', 'En proceso', StatusTone.active),
  completed('COMPLETADA', 'Completada', StatusTone.success),
  cancelled('CANCELADA', 'Cancelada', StatusTone.danger);

  const AppointmentStatus(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  /// Citas que aún pueden modificarse, confirmarse o cancelarse.
  bool get isEditable => this == pending || this == confirmed;

  static AppointmentStatus fromApi(String? value) =>
      AppointmentStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => AppointmentStatus.pending);
}

/// Estados de una orden de servicio.
enum OrderStatus {
  received('RECIBIDO', 'Recibido', StatusTone.neutral),
  diagnosis('DIAGNOSTICO', 'Diagnóstico', StatusTone.active),
  repairing('EN_REPARACION', 'En reparación', StatusTone.active),
  waitingPart('ESPERANDO_REFACCION', 'Esperando refacción', StatusTone.warning),
  finished('TERMINADO', 'Terminado', StatusTone.success),
  delivered('ENTREGADO', 'Entregado', StatusTone.success);

  const OrderStatus(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static OrderStatus fromApi(String? value) =>
      OrderStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => OrderStatus.received);
}
