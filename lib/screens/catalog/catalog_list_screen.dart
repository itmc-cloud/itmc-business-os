import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/service_catalog_item.dart';
import '../../providers/catalog_provider.dart';
import 'catalog_form_screen.dart';

class CatalogListScreen extends StatelessWidget {
  const CatalogListScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, ServiceCatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text('This will permanently remove "${item.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CatalogProvider>().deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Catalog')),
      body: Consumer<CatalogProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = provider.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('No services yet. Tap + to add one.'),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                confirmDismiss: (_) async {
                  await _confirmDelete(context, item);
                  return false;
                },
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.description),
                  trailing: Text('${item.defaultRate.toStringAsFixed(2)} / ${item.unit}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CatalogFormScreen(item: item),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CatalogFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
