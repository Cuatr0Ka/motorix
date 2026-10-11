import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ticket.dart';
import 'formatters.dart';
import 'status_labels.dart';

/// Imprime un ticket. Es una interfaz para poder sustituirla en las pruebas.
abstract class TicketPrinter {
  const TicketPrinter();

  /// Abre el diálogo de impresión del sistema con el ticket. Devuelve `true` si se envió a imprimir.
  Future<bool> printTicket(Ticket ticket);
}

/// Implementación real: arma el documento EN MEMORIA y lo envía al diálogo de impresión del sistema.
/// No guarda ningún archivo (aclaración 4); «Guardar como PDF» sigue disponible en el diálogo de Windows.
class SystemTicketPrinter extends TicketPrinter {
  const SystemTicketPrinter();

  @override
  Future<bool> printTicket(Ticket ticket) async {
    final content = ticket.content;
    if (content == null) return false;
    final document = buildTicketDocument(ticket, theme: await _loadTheme());
    return Printing.layoutPdf(name: ticket.folio, onLayout: (_) async => document.save());
  }
}

/// Tipografía del sistema de diseño (IBM Plex Sans) para que las tildes y la eñe se impriman bien. Se descarga la
/// primera vez (el paquete la guarda en caché); si no hay conexión se usa la fuente estándar del PDF.
Future<pw.ThemeData?> _loadTheme() async {
  try {
    return pw.ThemeData.withFont(base: await PdfGoogleFonts.iBMPlexSansRegular(), bold: await PdfGoogleFonts.iBMPlexSansBold());
  } catch (_) {
    return null;
  }
}

/// Documento de impresión del ticket (formato angosto de ticket). Con [theme] usa una tipografía Unicode; sin él, la
/// fuente estándar del PDF (cubre el texto sin tildes).
pw.Document buildTicketDocument(Ticket ticket, {pw.ThemeData? theme}) {
  final content = ticket.content!;
  final document = pw.Document(title: 'Ticket ${ticket.folio}', theme: theme);
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);
  const small = pw.TextStyle(fontSize: 8);
  const normal = pw.TextStyle(fontSize: 9);

  pw.Widget row(String left, String right, {pw.TextStyle style = normal}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [pw.Expanded(child: pw.Text(left, style: style)), pw.SizedBox(width: 6), pw.Text(right, style: style)],
      );

  pw.Widget section(String title, List<pw.Widget> children) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [pw.SizedBox(height: 6), pw.Text(title, style: bold), pw.Divider(thickness: 0.5, height: 4), ...children],
      );

  document.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text(content.shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
          if (content.shopAddress.isNotEmpty) pw.Center(child: pw.Text(content.shopAddress, style: small)),
          if (content.shopPhone.isNotEmpty) pw.Center(child: pw.Text('Tel. ${content.shopPhone}', style: small)),
          pw.SizedBox(height: 6),
          row('Ticket', ticket.folio, style: bold),
          row('Orden', content.orderFolio),
          row('Fecha', formatDateTime(content.generatedAt)),
          section('Cliente', [
            pw.Text(content.customerName, style: normal),
            if (content.customerPhone != null && content.customerPhone!.isNotEmpty) pw.Text('Tel. ${content.customerPhone}', style: small),
          ]),
          section('Vehiculo', [
            pw.Text(content.vehicleLabel, style: normal),
            row('Placas', content.plate),
            if (content.mileage != null) row('Kilometraje', formatMileage(content.mileage!)),
          ]),
          if (content.services.isNotEmpty)
            section('Servicios', [for (final line in content.services) row(line.description, formatMoney(line.amount))]),
          if (content.parts.isNotEmpty)
            section('Refacciones', [for (final part in content.parts) row(part.name, '${part.quantity} ${part.unit}')]),
          if (content.labor.isNotEmpty)
            section('Mano de obra', [for (final line in content.labor) row(line.description, formatMoney(line.amount))]),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, height: 4),
          row('Subtotal servicios', formatMoney(content.servicesTotal)),
          row('Subtotal mano de obra', formatMoney(content.laborTotal)),
          row('TOTAL', formatMoney(content.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          section('Pago', [
            row('Metodo', PaymentMethod.fromApi(content.paymentMethod).label),
            row('Estado', PaymentStatus.fromApi(content.paymentStatus).label),
            if (content.paidAt != null) row('Fecha de pago', formatDateTime(content.paidAt!)),
            if (content.paymentReference != null && content.paymentReference!.isNotEmpty) row('Referencia', content.paymentReference!),
          ]),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('Gracias por su preferencia', style: small)),
        ],
      ),
    ),
  );
  return document;
}
