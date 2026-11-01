import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';

/// Vista de un ticket con formato de comprobante: datos del taller, cliente, vehículo, conceptos, totales y pago.
/// Muestra solo la instantánea guardada, con el diseño de su formato: en la versión 2 (Sprint 5) cada refacción lleva
/// cantidad, precio unitario e importe y hay tres subtotales; los tickets anteriores (versión 1) se muestran exactamente
/// como se emitieron, con las refacciones solo con su cantidad.
class TicketView extends StatelessWidget {
  const TicketView({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final content = ticket.content;
    if (content == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    Widget row(String left, String right, {TextStyle? style, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(left, style: style ?? theme.textTheme.bodyMedium)),
              const SizedBox(width: AppSpacing.md),
              Text(right, key: key, style: style ?? theme.textTheme.bodyMedium),
            ],
          ),
        );

    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(title, style: bold),
            const Divider(height: AppSpacing.md),
            ...children,
          ],
        );

    return Container(
      key: const ValueKey('ticket'),
      width: 420,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(content.shopName, style: theme.textTheme.titleMedium, textAlign: TextAlign.center)),
          if (content.shopAddress.isNotEmpty) Center(child: Text(content.shopAddress, style: theme.textTheme.bodySmall, textAlign: TextAlign.center)),
          if (content.shopPhone.isNotEmpty) Center(child: Text('Tel. ${content.shopPhone}', style: theme.textTheme.bodySmall)),
          const SizedBox(height: AppSpacing.md),
          row('Ticket', ticket.folio, style: bold, key: const ValueKey('ticket-folio')),
          row('Orden', content.orderFolio),
          row('Fecha', formatDateTime(content.generatedAt)),
          section('Cliente', [
            Text(content.customerName, style: theme.textTheme.bodyMedium),
            if (content.customerPhone != null && content.customerPhone!.isNotEmpty)
              Text('Tel. ${content.customerPhone}', style: theme.textTheme.bodySmall),
          ]),
          section('Vehículo', [
            Text(content.vehicleLabel, style: theme.textTheme.bodyMedium),
            row('Placas', content.plate),
            if (content.mileage != null) row('Kilometraje', formatMileage(content.mileage!)),
          ]),
          if (content.services.isNotEmpty)
            section('Servicios realizados', [for (final line in content.services) row(line.description, formatMoney(line.amount))]),
          if (content.parts.isNotEmpty)
            section('Refacciones utilizadas', [
              for (final part in content.parts)
                if (content.isV2 && part.amount != null) ...[
                  row('${part.name} (${part.code})', formatMoney(part.amount!), key: ValueKey('ticket-importe-${part.code}')),
                  Text(
                    '${part.quantity} ${part.unit} × ${formatMoney(part.unitPrice ?? '0.00')}',
                    key: ValueKey('ticket-detalle-${part.code}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ] else
                  row('${part.name} (${part.code})', '${part.quantity} ${part.unit}'),
            ]),
          if (content.labor.isNotEmpty)
            section('Mano de obra', [for (final line in content.labor) row(line.description, formatMoney(line.amount))]),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: AppSpacing.md),
          row('Subtotal de servicios', formatMoney(content.servicesTotal)),
          row('Subtotal de mano de obra', formatMoney(content.laborTotal)),
          if (content.isV2 && content.partsTotal != null)
            row('Subtotal de refacciones', formatMoney(content.partsTotal!), key: const ValueKey('ticket-subtotal-refacciones')),
          row('Total', formatMoney(content.total), style: theme.textTheme.titleMedium, key: const ValueKey('ticket-total')),
          section('Pago', [
            row('Método de pago', PaymentMethod.fromApi(content.paymentMethod).label),
            row('Estado del pago', PaymentStatus.fromApi(content.paymentStatus).label),
            if (content.paidAt != null) row('Fecha de pago', formatDateTime(content.paidAt!)),
            if (content.paymentReference != null && content.paymentReference!.isNotEmpty) row('Referencia', content.paymentReference!),
          ]),
        ],
      ),
    );
  }
}
