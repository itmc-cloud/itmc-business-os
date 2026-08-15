import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/estimate.dart';
import '../../models/invoice.dart';
import '../../models/line_item.dart';
import '../../pdf/pdf_generator.dart';
import '../../providers/client_provider.dart';
import '../../providers/estimate_provider.dart';
import '../../providers/invoice_provider.dart';
import '../invoices/invoice_detail_screen.dart';
import 'estimate_form_screen.dart';

/// Read-only view of an [Estimate], looked up live from [EstimateProvider]
/// by [estimateId] so edits made via the form screen are reflected.
class EstimateDetailScreen extends StatelessWidget {
  const EstimateDetailScreen({super.key, required this.estimateId});

  final String estimateId;

  Future<void> _exportPdf(BuildContext context, Estimate estimate) async {
    final client = context.read<ClientProvider>().getById(estimate.clientId);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client not found')),
      );
      return;
    }
    final bytes = await buildEstimatePdf(estimate, client);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'estimate_${estimate.id}.pdf',
    );
  }

  Future<void> _convertToInvoice(BuildContext context, Estimate estimate) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final dueDate = estimate.date.add(const Duration(days: 30));

    final invoice = Invoice(
      id: invoiceProvider.newId(),
      clientId: estimate.clientId,
      title: estimate.title,
      date: estimate.date,
      items: estimate.items.map((i) => LineItem.fromJson(i.toJson())).toList(),
      taxRatePercent: estimate.taxRatePercent,
      discountPercent: estimate.discountPercent,
      notes: estimate.notes,
      status: InvoiceStatus.draft,
      currencyCode: estimate.currencyCode,
      invoiceNumber: InvoiceProvider.generateInvoiceNumber(),
      dueDate: dueDate,
      sourceEstimateId: estimate.id,
    );

    await invoiceProvider.saveInvoice(invoice);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$');

    return Consumer<EstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.getById(estimateId);
        if (estimate == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Estimate')),
            body: const Center(child: Text('Estimate not found.')),
          );
        }

        final client = context.watch<ClientProvider>().getById(estimate.clientId);

        return Scaffold(
          appBar: AppBar(
            title: Text(estimate.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EstimateFormScreen(estimate: estimate),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Client', style: Theme.of(context).textTheme.labelLarge),
              Text(client?.name ?? 'Unknown client'),
              const SizedBox(height: 12),
              Text('Date', style: Theme.of(context).textTheme.labelLarge),
              Text(DateFormat.yMMMd().format(estimate.date)),
              const SizedBox(height: 12),
              Text('Status', style: Theme.of(context).textTheme.labelLarge),
              Text(estimate.status),
              const SizedBox(height: 20),
              Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...estimate.items.map(
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
                      _totalsRow(context, 'Subtotal', currency.format(estimate.subtotal)),
                      _totalsRow(
                        context,
                        'Discount (${estimate.discountPercent.toStringAsFixed(1)}%)',
                        '-${currency.format(estimate.discountAmount)}',
                      ),
                      _totalsRow(
                        context,
                        'Tax (${estimate.taxRatePercent.toStringAsFixed(1)}%)',
                        currency.format(estimate.taxAmount),
                      ),
                      const Divider(),
                      _totalsRow(context, 'Total', currency.format(estimate.total), bold: true),
                    ],
                  ),
                ),
              ),
              if (estimate.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(estimate.notes),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _exportPdf(context, estimate),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _convertToInvoice(context, estimate),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Convert to Invoice'),
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
