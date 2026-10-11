import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ticket.dart';
import '../services/api_client.dart';
import '../services/tickets_service.dart';
import '../utils/ticket_printer.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/ticket_view.dart';

/// Pantalla de un ticket: lo muestra con formato de comprobante y permite imprimirlo (solo su contenido, sin menús
/// ni botones) mediante el diálogo de impresión del sistema. No genera ni guarda archivos.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  Ticket? _ticket;
  String? _error;
  bool _loading = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await context.read<TicketsService>().get(widget.ticketId);
      if (mounted) setState(() => _ticket = ticket);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print(Ticket ticket) async {
    setState(() => _printing = true);
    try {
      final sent = await context.read<TicketPrinter>().printTicket(ticket);
      if (!mounted) return;
      if (sent) {
        showSuccess(context, 'Ticket enviado a imprimir.');
      } else {
        showFailure(context, 'No se imprimió el ticket. Inténtalo de nuevo.');
      }
    } catch (_) {
      if (mounted) showFailure(context, 'No se pudo abrir la impresión. Revisa la impresora e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: ticket == null ? 'Ticket' : 'Ticket ${ticket.folio}',
            subtitle: ticket == null ? null : 'Comprobante de la orden ${ticket.orderFolio}',
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (ticket != null)
                FilledButton.icon(
                  key: const ValueKey('imprimir-ticket'),
                  onPressed: _printing ? null : () => _print(ticket),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(_printing ? 'Imprimiendo…' : 'Imprimir'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _loading && ticket == null
                ? const LoadingView()
                : _error != null && ticket == null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : ticket == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: TicketView(ticket: ticket))),
          ),
        ],
      ),
    );
  }
}
