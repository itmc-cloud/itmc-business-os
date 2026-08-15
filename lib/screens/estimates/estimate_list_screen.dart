import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/estimate.dart';
import '../../providers/client_provider.dart';
import '../../providers/estimate_provider.dart';
import 'estimate_detail_screen.dart';
import 'estimate_form_screen.dart';

class EstimateListScreen extends StatelessWidget {
  const EstimateListScreen({super.key});

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case EstimateStatus.accepted:
        return Colors.green;
      case EstimateStatus.rejected:
        return scheme.error;
      case EstimateStatus.sent:
        return Colors.orange;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$');

    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
      body: Consumer2<EstimateProvider, ClientProvider>(
        builder: (context, estimateProvider, clientProvider, _) {
          if (estimateProvider.isLoading && estimateProvider.estimates.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final estimates = estimateProvider.estimates;
          if (estimates.isEmpty) {
            return const Center(child: Text('No estimates yet. Tap + to create one.'));
          }
          return ListView.builder(
            itemCount: estimates.length,
            itemBuilder: (context, index) {
              final estimate = estimates[index];
              final client = clientProvider.getById(estimate.clientId);
              return ListTile(
                title: Text(estimate.title),
                subtitle: Text(client?.name ?? 'Unknown client'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currency.format(estimate.total)),
                    Text(
                      estimate.status,
                      style: TextStyle(
                        color: _statusColor(context, estimate.status),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EstimateDetailScreen(estimateId: estimate.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EstimateFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
