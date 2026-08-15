import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../providers/client_provider.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_detail_screen.dart';
import 'invoice_form_screen.dart';

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return scheme.error;
      case InvoiceStatus.sent:
        return Colors.orange;
      default:
        return scheme.outline;
    }
  }

  void _createBlankInvoice(BuildContext context) {
    final clientProvider = context.read<ClientProvider>();

    if (clientProvider.clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a client first')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$');

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: Consumer2<InvoiceProvider, ClientProvider>(
        builder: (context, invoiceProvider, clientProvider, _) {
          if (invoiceProvider.isLoading && invoiceProvider.invoices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoices = invoiceProvider.invoices;
          if (invoices.isEmpty) {
            return const Center(child: Text('No invoices yet. Tap + to create one.'));
          }
          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              final client = clientProvider.getById(invoice.clientId);
              return ListTile(
                title: Text(invoice.invoiceNumber),
                subtitle: Text(client?.name ?? 'Unknown client'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currency.format(invoice.total)),
                    Text(
                      invoice.status,
                      style: TextStyle(
                        color: _statusColor(context, invoice.status),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createBlankInvoice(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
