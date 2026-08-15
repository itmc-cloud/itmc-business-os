import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/client.dart';
import '../models/estimate.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';

/// Pure helpers that turn domain models into PDF bytes.
///
/// No I/O happens here (no sharing/printing) — callers are responsible for
/// doing something with the returned bytes (e.g. `Printing.sharePdf`).

NumberFormat _currencyFormat(String currencyCode) {
  try {
    return NumberFormat.currency(name: currencyCode);
  } catch (_) {
    return NumberFormat.currency(symbol: '$currencyCode ');
  }
}

pw.Widget _buildHeader(String docTitle, String docSubtitle) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        docTitle,
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(docSubtitle, style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 16),
      pw.Divider(),
    ],
  );
}

pw.Widget _buildClientBlock(Client client) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Bill To',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(client.name),
      if (client.company.isNotEmpty) pw.Text(client.company),
      if (client.email.isNotEmpty) pw.Text(client.email),
      if (client.phone.isNotEmpty) pw.Text(client.phone),
      if (client.address.isNotEmpty) pw.Text(client.address),
    ],
  );
}

pw.Widget _buildItemsTable(List<LineItem> items, NumberFormat currency) {
  final headers = ['Description', 'Qty', 'Unit Price', 'Total'];
  final data = items
      .map(
        (item) => [
          item.description,
          item.quantity.toStringAsFixed(2),
          currency.format(item.unitPrice),
          currency.format(item.total),
        ],
      )
      .toList();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(2),
      3: const pw.FlexColumnWidth(2),
    },
  );
}

pw.Widget _totalsRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(
    fontSize: 11,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}

pw.Widget _buildTotalsBlock({
  required double subtotal,
  required double discountAmount,
  required double taxAmount,
  required double total,
  required double discountPercent,
  required double taxRatePercent,
  required NumberFormat currency,
}) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 220,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _totalsRow('Subtotal', currency.format(subtotal)),
          if (discountPercent != 0)
            _totalsRow(
              'Discount (${discountPercent.toStringAsFixed(1)}%)',
              '-${currency.format(discountAmount)}',
            ),
          if (taxRatePercent != 0)
            _totalsRow(
              'Tax (${taxRatePercent.toStringAsFixed(1)}%)',
              currency.format(taxAmount),
            ),
          pw.Divider(),
          _totalsRow('Total', currency.format(total), bold: true),
        ],
      ),
    ),
  );
}

Future<Uint8List> buildEstimatePdf(Estimate estimate, Client client) async {
  final currency = _currencyFormat(estimate.currencyCode);
  final dateStr = DateFormat.yMMMd().format(estimate.date);
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _buildHeader('Estimate', estimate.title),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildClientBlock(client),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: $dateStr'),
                pw.Text('Status: ${estimate.status}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        _buildItemsTable(estimate.items, currency),
        pw.SizedBox(height: 16),
        _buildTotalsBlock(
          subtotal: estimate.subtotal,
          discountAmount: estimate.discountAmount,
          taxAmount: estimate.taxAmount,
          total: estimate.total,
          discountPercent: estimate.discountPercent,
          taxRatePercent: estimate.taxRatePercent,
          currency: currency,
        ),
        if (estimate.notes.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            'Notes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(estimate.notes, style: const pw.TextStyle(fontSize: 10)),
        ],
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> buildInvoicePdf(Invoice invoice, Client client) async {
  final currency = _currencyFormat(invoice.currencyCode);
  final dateStr = DateFormat.yMMMd().format(invoice.date);
  final dueDateStr = DateFormat.yMMMd().format(invoice.dueDate);
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _buildHeader('Invoice', invoice.title),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildClientBlock(client),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Invoice #: ${invoice.invoiceNumber}'),
                pw.Text('Date: $dateStr'),
                pw.Text('Due: $dueDateStr'),
                pw.Text('Status: ${invoice.status}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        _buildItemsTable(invoice.items, currency),
        pw.SizedBox(height: 16),
        _buildTotalsBlock(
          subtotal: invoice.subtotal,
          discountAmount: invoice.discountAmount,
          taxAmount: invoice.taxAmount,
          total: invoice.total,
          discountPercent: invoice.discountPercent,
          taxRatePercent: invoice.taxRatePercent,
          currency: currency,
        ),
        if (invoice.notes.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            'Notes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(invoice.notes, style: const pw.TextStyle(fontSize: 10)),
        ],
      ],
    ),
  );

  return doc.save();
}
