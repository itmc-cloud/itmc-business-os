import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../pdf/pdf_generator.dart';
import '../../providers/client_provider.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_form_screen.dart';

/// Read-only view of an [Invoice], looked up live from [InvoiceProvider]
/// by [invoiceId] so edits made via the form screen are reflected.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  Future<void> _exportPdf(BuildContext context, Invoice invoice) async {
    final client = context.read<ClientProvider>().getById(invoice.clientId);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client not found')),
      );
      return;
    }
    final bytes = await buildInvoicePdf(invoice, client);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${invoice.invoiceNumber}.pdf',
    );
  }

  Future<void> _changeStatus(BuildContext context, Invoice invoice, String newStatus) async {
    invoice.status = newStatus;
    await context.read<InvoiceProvider>().updateInvoice(invoice);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$');

    return Consumer<InvoiceProvider>(
      builder: (context, provider, _) {
        final invoice = provider.getById(invoiceId);
        if (invoice == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Invoice')),
            body: const Center(child: Text('Invoice not found.')),
          );
        }

        final client = context.watch<ClientProvider>().getById(invoice.clientId);

        return Scaffold(
          appBar: AppBar(
            title: Text(invoice.invoiceNumber),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Change status',
                icon: const Icon(Icons.flag_outlined),
                onSelected: (status) => _changeStatus(context, invoice, status),
                itemBuilder: (context) => InvoiceStatus.values
                    .map((s) => PopupMenuItem(value: s, child: Text('Mark as $s')))
                    .toList(),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceFormScreen(invoice: invoice),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(invoice.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('Client', style: Theme.of(context).textTheme.labelLarge),
              Text(client?.name ?? 'Unknown client'),
              const SizedBox(height: 12),
              Text('Date', style: Theme.of(context).textTheme.labelLarge),
              Text(DateFormat.yMMMd().format(invoice.date)),
              const SizedBox(height: 12),
              Text('Due Date', style: Theme.of(context).textTheme.labelLarge),
              Text(DateFormat.yMMMd().format(invoice.dueDate)),
              const SizedBox(height: 12),
              Text('Status', style: Theme.of(context).textTheme.labelLarge),
              Text(invoice.status),
              if (invoice.sourceEstimateId != null) ...[
                const SizedBox(height: 12),
                Text('Source Estimate', style: Theme.of(context).textTheme.labelLarge),
                Text(invoice.sourceEstimateId!),
              ],
              const SizedBox(height: 20),
              Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...invoice.items.map(
                (item) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(item.description),
                    subtitle: Text(
                      '${item.quantity.toStringAsFixed(2)} x ${currency.format(item.unitPrice)}',
                    ),
                    trailing: Text(currency.format(item.total)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _totalsRow(context, 'Subtotal', currency.format(invoice.subtotal)),
                      _totalsRow(
                        context,
                        'Discount (${invoice.discountPercent.toStringAsFixed(1)}%)',
                        '-${currency.format(invoice.discountAmount)}',
                      ),
                      _totalsRow(
                        context,
                        'Tax (${invoice.taxRatePercent.toStringAsFixed(1)}%)',
                        currency.format(invoice.taxAmount),
                      ),
                      const Divider(),
                      _totalsRow(context, 'Total', currency.format(invoice.total), bold: true),
                    ],
                  ),
                ),
              ),
              if (invoice.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(invoice.notes),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _exportPdf(context, invoice),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _totalsRow(BuildContext context, String label, String value, {bool bold = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
