import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/service_order.dart';
import '../services/api_client.dart';
import '../services/payments_service.dart';
import '../utils/formatters.dart';
import '../utils/link_opener.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import 'confirm_dialog.dart';
import 'panel_card.dart';
import 'payment_chip.dart';
import 'state_views.dart';

/// Acciones de la sección «Cobro». Cada una devuelve el mensaje de error del servidor, o null si salió bien.
class OrderBillingActions {
  const OrderBillingActions({
    required this.onCharge,
    required this.onRefresh,
    required this.onCancel,
    this.onGenerateTicket,
    this.onViewTicket,
  });

  final Future<String?> Function(PaymentMethod method, String? reference, String amount) onCharge;
  final Future<String?> Function(Payment payment) onRefresh;
  final Future<String?> Function(Payment payment) onCancel;

  /// Genera el ticket de la orden (solo con un pago Pagado y sin ticket).
  final Future<String?> Function()? onGenerateTicket;

  /// Abre el ticket existente.
  final void Function(TicketRef ticket)? onViewTicket;
}

/// Tarjeta «Cobro» del detalle de la orden (administración y recepción): total a cobrar, estado de cobro, pagos
/// de la orden y las acciones de cobro. El diálogo de cobro nunca pide datos de tarjeta.
class OrderBillingSection extends StatelessWidget {
  const OrderBillingSection({super.key, required this.order, required this.actions, this.busy = false});

  final ServiceOrder order;
  final OrderBillingActions actions;
  final bool busy;

  void _report(BuildContext context, String? failure, String success) {
    if (!context.mounted) return;
    if (failure == null) {
      showSuccess(context, success);
    } else {
      showFailure(context, failure);
    }
  }

  Future<void> _charge(BuildContext context, Billing billing) async {
    final request = await showDialog<({PaymentMethod method, String? reference})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChargeDialog(total: billing.total),
    );
    if (request == null || !context.mounted) return;
    final isMercadoPago = request.method == PaymentMethod.mercadoPago;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Registrar pago',
      message: '¿Confirmas el cobro de ${formatMoney(billing.total)} con ${request.method.label} para la orden ${order.folio}?'
          '${isMercadoPago ? ' Se creará un enlace de cobro de Mercado Pago para que el cliente pague.' : ''}',
      confirmLabel: 'Registrar pago',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await actions.onCharge(request.method, request.reference, billing.total);
    if (!context.mounted) return;
    _report(context, failure, isMercadoPago ? 'Cobro creado: comparte el enlace con el cliente.' : 'Pago registrado correctamente.');
  }

  Future<void> _copy(BuildContext context, Payment payment) async {
    await Clipboard.setData(ClipboardData(text: payment.checkoutUrl ?? ''));
    if (context.mounted) showSuccess(context, 'Enlace de cobro copiado.');
  }

  Future<void> _open(BuildContext context, Payment payment) async {
    final opened = await context.read<LinkOpener>().open(payment.checkoutUrl ?? '');
    if (!context.mounted) return;
    if (!opened) showFailure(context, 'No se pudo abrir el enlace de cobro. Cópialo y ábrelo en el navegador.');
  }

  Future<void> _refresh(BuildContext context, Payment payment) async {
    final failure = await actions.onRefresh(payment);
    if (!context.mounted) return;
    _report(context, failure, 'Estado del cobro actualizado.');
  }

  Future<void> _cancel(BuildContext context, Payment payment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar cobro',
      message: '¿Seguro que quieres cancelar el cobro pendiente de ${formatMoney(payment.amount)}? '
          'Se conserva en el historial y podrás cobrar de nuevo.',
      confirmLabel: 'Cancelar cobro',
      cancelLabel: 'Volver',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await actions.onCancel(payment);
    if (!context.mounted) return;
    _report(context, failure, 'Cobro cancelado.');
  }

  Future<void> _generateTicket(BuildContext context) async {
    final generate = actions.onGenerateTicket;
    if (generate == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Generar ticket',
      message: '¿Generar el ticket de la orden ${order.folio}? Conservará los datos y los importes tal como están ahora.',
      confirmLabel: 'Generar ticket',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await generate();
    if (!context.mounted) return;
    _report(context, failure, 'Ticket generado correctamente.');
  }

  Payment? _pendingPayment(Billing billing) {
    for (final payment in billing.payments) {
      if (payment.status == PaymentStatus.pending) return payment;
    }
    return null;
  }

  String? _cannotChargeReason(Billing billing) {
    if (billing.canCharge || billing.collectionStatus != CollectionStatus.unpaid) return null;
    if (!order.isFinishedOrDelivered) return 'La orden debe estar Terminada para poder cobrarse.';
    return 'La orden no tiene nada que cobrar: el total es cero.';
  }

  /// Cancela el pago pendiente desfasado, con confirmación. No crea otro: al terminar, la recepción cobra de nuevo con
  /// el total vigente (el sistema nunca cancela ni crea pagos por sí solo).
  Future<void> _cancelOutdated(BuildContext context, Payment payment, Billing billing) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar pago y generar uno nuevo',
      message: 'El pago pendiente es de ${formatMoney(payment.amount)} y el total vigente de la orden es '
          '${formatMoney(billing.total)}. Se cancelará ese pago (queda en el historial) y después podrás cobrar con el total vigente.',
      confirmLabel: 'Cancelar pago',
      cancelLabel: 'Volver',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await actions.onCancel(payment);
    if (!context.mounted) return;
    _report(context, failure, 'Pago cancelado. Usa «Cobrar» para generar uno nuevo con el total vigente.');
  }

  /// Aviso del pago pendiente cuyo importe ya no coincide con el total, con el botón para cancelarlo (FR-012).
  Widget _outdatedPendingNotice(BuildContext context, Billing billing, Payment payment) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('importe-desfasado'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'El importe del pago pendiente (${formatMoney(payment.amount)}) ya no coincide con el total de la orden '
            '(${formatMoney(billing.total)}).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('cancelar-y-generar-nuevo'),
            onPressed: busy ? null : () => _cancelOutdated(context, payment, billing),
            icon: const Icon(Icons.sync_problem_outlined, size: 18),
            label: const Text('Cancelar pago y generar uno nuevo'),
          ),
        ],
      ),
    );
  }

  /// Aviso de la diferencia entre el total vigente y el pago Pagado: no se cobra desde aquí, se resuelve fuera.
  Widget _differenceNotice(BuildContext context, Billing billing) {
    final amount = double.tryParse(billing.amountDifference) ?? 0;
    final text = amount > 0
        ? 'El total de la orden supera el pago registrado por ${formatMoney(billing.amountDifference)}. La diferencia se cobra fuera del sistema.'
        : 'El pago registrado supera el total de la orden por ${formatMoney(amount.abs().toStringAsFixed(2))}.';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        key: const ValueKey('diferencia-por-cobrar'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = order.billing;
    if (billing == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final reason = _cannotChargeReason(billing);

    return PanelCard(
      title: 'Cobro',
      trailing: billing.canCharge
          ? FilledButton.icon(
              key: const ValueKey('cobrar'),
              onPressed: busy ? null : () => _charge(context, billing),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Cobrar'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Total a cobrar: ', style: theme.textTheme.bodyMedium),
                  TextSpan(
                    text: formatMoney(billing.total),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ])),
              ),
              CollectionChip(status: billing.collectionStatus),
            ],
          ),
          if (billing.breakdown != null) _Breakdown(breakdown: billing.breakdown!),
          if (billing.amountOutdated && !billing.isPaid && _pendingPayment(billing) != null)
            _outdatedPendingNotice(context, billing, _pendingPayment(billing)!),
          if (billing.isPaid && billing.hasDifference) _differenceNotice(context, billing),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(reason, key: const ValueKey('motivo-sin-cobro'), style: theme.textTheme.bodySmall),
            ),
          if (billing.payments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            for (final payment in billing.payments)
              _PaymentRow(
                payment: payment,
                busy: busy,
                onCopy: () => _copy(context, payment),
                onOpen: () => _open(context, payment),
                onRefresh: () => _refresh(context, payment),
                onCancel: () => _cancel(context, payment),
              ),
          ],
          if (billing.ticket != null || (billing.isPaid && actions.onGenerateTicket != null))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (billing.ticket != null)
                    OutlinedButton.icon(
                      key: const ValueKey('ver-ticket'),
                      onPressed: busy || actions.onViewTicket == null ? null : () => actions.onViewTicket!(billing.ticket!),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text('Ver ticket ${billing.ticket!.folio}'),
                    )
                  else
                    OutlinedButton.icon(
                      key: const ValueKey('generar-ticket'),
                      onPressed: busy ? null : () => _generateTicket(context),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Generar ticket'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Desglose del total antes de registrar el pago: servicios, mano de obra y refacciones (cantidad, precio e importe)
/// con sus subtotales (FR-023). Las líneas anteriores a los precios muestran 0.00 y «Anterior a los precios». Sirve a la
/// recepción para revisar que una pieza no se haya cobrado ya como servicio.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.breakdown});

  final BillingBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    Widget row(String left, String right, {TextStyle? style, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(left, style: style ?? theme.textTheme.bodySmall)),
              const SizedBox(width: AppSpacing.md),
              Text(right, key: key, style: style ?? theme.textTheme.bodySmall),
            ],
          ),
        );

    Widget group(String title, String subtotal, Key subtotalKey, List<Widget> lines) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            row(title, formatMoney(subtotal), style: bold, key: subtotalKey),
            if (lines.isEmpty) Text('Sin conceptos.', style: theme.textTheme.bodySmall) else ...lines,
          ],
        );

    return Column(
      key: const ValueKey('desglose-cobro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        Text('Desglose del total', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        group('Servicios', breakdown.servicesSubtotal, const ValueKey('subtotal-servicios'), [
          for (final line in breakdown.services) row(line.description, formatMoney(line.amount)),
        ]),
        group('Mano de obra', breakdown.laborSubtotal, const ValueKey('subtotal-mano-de-obra'), [
          for (final line in breakdown.labor) row(line.description, formatMoney(line.amount)),
        ]),
        group('Refacciones', breakdown.partsSubtotal, const ValueKey('subtotal-refacciones-cobro'), [
          for (final part in breakdown.parts)
            row(
              '${part.code} · ${part.name}  ${part.quantity} ${part.unit}'
              '${part.legacy ? '  ·  Anterior a los precios' : '  ×  ${formatMoney(part.unitPrice)}'}',
              formatMoney(part.amount),
              key: ValueKey('importe-cobro-${part.id}'),
            ),
        ]),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.busy,
    required this.onCopy,
    required this.onOpen,
    required this.onRefresh,
    required this.onCancel,
  });

  final Payment payment;
  final bool busy;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = payment.paidAt ?? payment.createdAt;
    return Padding(
      key: ValueKey('pago-${payment.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${payment.method.label} · ${formatMoney(payment.amount)} · ${formatDateTime(when)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              PaymentChip(status: payment.status),
            ],
          ),
          if (payment.reference != null && payment.reference!.isNotEmpty)
            Text('Referencia: ${payment.reference}', style: theme.textTheme.bodySmall),
          if (payment.externalPaymentId != null) Text('Operación de Mercado Pago: ${payment.externalPaymentId}', style: theme.textTheme.bodySmall),
          if (payment.isPendingMercadoPago) ...[
            if (payment.checkoutUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(payment.checkoutUrl!, key: ValueKey('enlace-${payment.id}'), style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ),
            if (payment.lastCheckedAt != null)
              Text('Última consulta: ${formatDateTime(payment.lastCheckedAt!)}', style: theme.textTheme.bodySmall),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  key: ValueKey('copiar-enlace-${payment.id}'),
                  onPressed: busy ? null : onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copiar enlace'),
                ),
                TextButton.icon(
                  key: ValueKey('abrir-enlace-${payment.id}'),
                  onPressed: busy ? null : onOpen,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Abrir enlace'),
                ),
                TextButton.icon(
                  key: ValueKey('actualizar-pago-${payment.id}'),
                  onPressed: busy ? null : onRefresh,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Actualizar estado'),
                ),
                TextButton.icon(
                  key: ValueKey('cancelar-pago-${payment.id}'),
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar cobro'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Diálogo de cobro: método (los no disponibles aparecen deshabilitados con su leyenda) y referencia opcional. Nunca pide
/// número de tarjeta, vencimiento ni código de seguridad; la referencia rechaza textos que parezcan un número de tarjeta.
class _ChargeDialog extends StatefulWidget {
  const _ChargeDialog({required this.total});

  final String total;

  @override
  State<_ChargeDialog> createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<_ChargeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  List<PaymentMethodOption>? _methods;
  String? _loadError;
  PaymentMethod _selected = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _methods = null;
      _loadError = null;
    });
    try {
      final methods = await context.read<PaymentsService>().methods();
      if (mounted) setState(() => _methods = methods);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  /// Misma regla del servidor: 13 a 19 dígitos (con espacios o guiones) que cumplen el algoritmo de Luhn.
  static bool looksLikeCardNumber(String text) {
    for (final match in RegExp(r'(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)').allMatches(text)) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      var sum = 0;
      var doubleIt = false;
      for (var i = digits.length - 1; i >= 0; i--) {
        var digit = int.parse(digits[i]);
        if (doubleIt) {
          digit *= 2;
          if (digit > 9) digit -= 9;
        }
        sum += digit;
        doubleIt = !doubleIt;
      }
      if (sum % 10 == 0) return true;
    }
    return false;
  }

  String? _validateReference(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 100) return 'La referencia no puede pasar de 100 caracteres.';
    if (looksLikeCardNumber(text)) {
      return 'Parece un número de tarjeta. No captures números de tarjeta: escribe solo el folio de la operación.';
    }
    return null;
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final reference = _reference.text.trim();
    Navigator.of(context).pop((method: _selected, reference: reference.isEmpty ? null : reference));
  }

  @override
  Widget build(BuildContext context) {
    final methods = _methods;
    final theme = Theme.of(context);
    final usesReference = _selected != PaymentMethod.mercadoPago;
    return AlertDialog(
      title: const Text('Cobrar la orden'),
      content: SizedBox(
        width: 460,
        child: methods == null && _loadError == null
            ? const SizedBox(height: 80, child: LoadingView(label: 'Cargando métodos de pago…'))
            : _loadError != null
                ? ErrorView(message: _loadError!, onRetry: _load)
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total a cobrar: ${formatMoney(widget.total)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppSpacing.md),
                        RadioGroup<PaymentMethod>(
                          groupValue: _selected,
                          onChanged: (value) {
                            if (value != null) setState(() => _selected = value);
                          },
                          child: Column(
                            children: [
                              for (final option in methods!)
                                RadioListTile<PaymentMethod>(
                                  key: ValueKey('metodo-${option.method.apiValue}'),
                                  value: option.method,
                                  enabled: option.available,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(option.method.label),
                                  subtitle: option.available ? null : Text(option.reason ?? 'No disponible'),
                                ),
                            ],
                          ),
                        ),
                        if (usesReference) ...[
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            key: const ValueKey('referencia-pago'),
                            controller: _reference,
                            decoration: InputDecoration(
                              labelText: 'Referencia (opcional)',
                              helperText: _selected == PaymentMethod.card
                                  ? 'Folio de la terminal. Nunca captures el número de la tarjeta.'
                                  : 'Folio o clave de rastreo de la operación.',
                            ),
                            validator: _validateReference,
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(key: const ValueKey('continuar-cobro'), onPressed: methods == null ? null : _continue, child: const Text('Continuar')),
      ],
    );
  }
}
