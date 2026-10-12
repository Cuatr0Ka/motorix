import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tono visual de un estado (convención de color de `docs/design-system.md`).
enum StatusTone {
  neutral(AppColors.textSecondary),
  active(AppColors.info),
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

/// Indicador de un mantenimiento pendiente (calculado por el servidor). El color nunca es la única señal.
enum MaintenanceIndicator {
  normal('NORMAL', 'Normal', StatusTone.success),
  upcoming('PROXIMO', 'Próximo', StatusTone.warning),
  overdue('VENCIDO', 'Vencido', StatusTone.danger);

  const MaintenanceIndicator(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static MaintenanceIndicator? fromApi(String? value) {
    for (final item in MaintenanceIndicator.values) {
      if (item.apiValue == value) return item;
    }
    return null;
  }
}

/// Estado de stock de una refacción: Suficiente, Bajo (en o bajo el mínimo) o Agotado (cero).
enum StockStatus {
  sufficient('SUFICIENTE', 'Suficiente', StatusTone.success),
  low('BAJO', 'Bajo', StatusTone.warning),
  outOfStock('AGOTADO', 'Agotado', StatusTone.danger);

  const StockStatus(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static StockStatus fromApi(String? value) =>
      StockStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => StockStatus.sufficient);
}

/// Estado de un pago. El color nunca es la única señal: cada chip lleva texto.
enum PaymentStatus {
  pending('PENDIENTE', 'Pendiente', StatusTone.warning),
  paid('PAGADO', 'Pagado', StatusTone.success),
  rejected('RECHAZADO', 'Rechazado', StatusTone.danger),
  cancelled('CANCELADO', 'Cancelado', StatusTone.neutral);

  const PaymentStatus(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static PaymentStatus fromApi(String? value) =>
      PaymentStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => PaymentStatus.pending);
}

/// Método de pago.
enum PaymentMethod {
  cash('EFECTIVO', 'Efectivo'),
  card('TARJETA', 'Tarjeta'),
  transfer('TRANSFERENCIA', 'Transferencia'),
  mercadoPago('MERCADO_PAGO', 'Mercado Pago');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String? value) =>
      PaymentMethod.values.firstWhere((m) => m.apiValue == value, orElse: () => PaymentMethod.cash);
}

/// Estado de cobro de una orden: Sin cobrar, Pendiente (cobro de Mercado Pago en curso) o Pagado.
enum CollectionStatus {
  unpaid('SIN_COBRAR', 'Sin cobrar', StatusTone.neutral),
  pending('PENDIENTE', 'Cobro pendiente', StatusTone.warning),
  paid('PAGADO', 'Pagado', StatusTone.success);

  const CollectionStatus(this.apiValue, this.label, this.tone);

  final String apiValue;
  final String label;
  final StatusTone tone;

  static CollectionStatus fromApi(String? value) =>
      CollectionStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => CollectionStatus.unpaid);
}
