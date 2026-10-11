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

  String? _cannotChargeReason(Billing billing) {
    if (billing.canCharge || billing.collectionStatus != CollectionStatus.unpaid) return null;
    if (!order.isFinishedOrDelivered) return 'La orden debe estar Terminada para poder cobrarse.';
    return 'La orden no tiene servicios ni mano de obra: no hay nada que cobrar.';
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
          if (billing.amountOutdated)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'El total cambió después del cobro. El pago conserva su importe (${formatMoney(billing.payments.firstWhere((p) => p.status == PaymentStatus.paid || p.status == PaymentStatus.pending, orElse: () => billing.payments.first).amount)}).',
                key: const ValueKey('importe-desactualizado'),
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
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
