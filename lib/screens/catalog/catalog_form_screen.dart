import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/service_catalog_item.dart';
import '../../providers/catalog_provider.dart';

/// Add/edit form for a [ServiceCatalogItem]. Pass an existing [item] to edit
/// it, or leave null to create a new one.
class CatalogFormScreen extends StatefulWidget {
  const CatalogFormScreen({super.key, this.item});

  final ServiceCatalogItem? item;

  @override
  State<CatalogFormScreen> createState() => _CatalogFormScreenState();
}

class _CatalogFormScreenState extends State<CatalogFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitController;
  late final TextEditingController _rateController;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _unitController = TextEditingController(text: item?.unit ?? 'hour');
    _rateController = TextEditingController(
      text: item != null ? item.defaultRate.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CatalogProvider>();
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

    if (_isEditing) {
      final item = widget.item!
        ..name = _nameController.text.trim()
        ..description = _descriptionController.text.trim()
        ..unit = _unitController.text.trim()
        ..defaultRate = rate;
      await provider.updateItem(item);
    } else {
      await provider.addItem(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        unit: _unitController.text.trim(),
        defaultRate: rate,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Service' : 'New Service'),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'hour, project, page...',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(labelText: 'Default Rate'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return double.tryParse(value.trim()) == null
                    ? 'Enter a valid number'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
