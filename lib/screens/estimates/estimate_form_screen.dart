import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/estimate.dart';
import '../../models/line_item.dart';
import '../../models/service_catalog_item.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/estimate_provider.dart';

/// Add/edit form for an [Estimate]. Pass an existing [estimate] to edit it,
/// or leave null to create a new one.
class EstimateFormScreen extends StatefulWidget {
  const EstimateFormScreen({super.key, this.estimate});

  final Estimate? estimate;

  @override
  State<EstimateFormScreen> createState() => _EstimateFormScreenState();
}

class _EstimateFormScreenState extends State<EstimateFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _taxController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  String? _clientId;
  late DateTime _date;
  late String _status;
  late List<LineItem> _items;

  bool get _isEditing => widget.estimate != null;

  @override
  void initState() {
    super.initState();
    final estimate = widget.estimate;
    _titleController = TextEditingController(text: estimate?.title ?? '');
    _taxController = TextEditingController(
      text: estimate != null ? estimate.taxRatePercent.toString() : '0',
    );
    _discountController = TextEditingController(
      text: estimate != null ? estimate.discountPercent.toString() : '0',
    );
    _notesController = TextEditingController(text: estimate?.notes ?? '');
    _clientId = estimate?.clientId;
    _date = estimate?.date ?? DateTime.now();
    _status = estimate?.status ?? EstimateStatus.draft;
    _items = estimate != null
        ? estimate.items
            .map((i) => LineItem(
                  id: i.id,
                  description: i.description,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                ))
            .toList()
        : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.total);
  double _discountPercent() => double.tryParse(_discountController.text.trim()) ?? 0.0;
  double _taxPercent() => double.tryParse(_taxController.text.trim()) ?? 0.0;
  double get _discountAmount => _subtotal * (_discountPercent() / 100.0);
  double get _taxAmount => (_subtotal - _discountAmount) * (_taxPercent() / 100.0);
  double get _total => _subtotal - _discountAmount + _taxAmount;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _addOrEditItem({LineItem? existing}) async {
    final catalog = context.read<CatalogProvider>().items;
    final result = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LineItemEditor(existing: existing, catalog: catalog),
    );
    if (result != null) {
      setState(() {
        if (existing != null) {
          final index = _items.indexWhere((i) => i.id == existing.id);
          if (index != -1) _items[index] = result;
        } else {
          _items.add(result);
        }
      });
    }
  }

  void _removeItem(LineItem item) {
    setState(() => _items.remove(item));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }

    final estimateProvider = context.read<EstimateProvider>();

    if (_isEditing) {
      final estimate = widget.estimate!
        ..clientId = _clientId!
        ..title = _titleController.text.trim()
        ..date = _date
        ..items = _items
        ..taxRatePercent = _taxPercent()
        ..discountPercent = _discountPercent()
        ..notes = _notesController.text.trim()
        ..status = _status;
      await estimateProvider.updateEstimate(estimate);
    } else {
      await estimateProvider.addEstimate(
        clientId: _clientId!,
        title: _titleController.text.trim(),
        date: _date,
        items: _items,
        taxRatePercent: _taxPercent(),
        discountPercent: _discountPercent(),
        notes: _notesController.text.trim(),
        status: _status,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<ClientProvider>().clients;
    final currency = NumberFormat.currency(symbol: r'$');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Estimate' : 'New Estimate'),
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
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              decoration: const InputDecoration(labelText: 'Client'),
              items: clients
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (value) => setState(() => _clientId = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: EstimateStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => _addOrEditItem(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No items yet.'),
              ),
            ..._items.map(
              (item) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.quantity.toStringAsFixed(2)} x ${currency.format(item.unitPrice)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currency.format(item.total)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeItem(item),
                      ),
                    ],
                  ),
                  onTap: () => _addOrEditItem(existing: item),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _taxController,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    decoration: const InputDecoration(labelText: 'Discount %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _TotalsSummary(
              subtotal: _subtotal,
              discountAmount: _discountAmount,
              taxAmount: _taxAmount,
              total: _total,
              currency: currency,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save Estimate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsSummary extends StatelessWidget {
  const _TotalsSummary({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.currency,
  });

  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Subtotal', currency.format(subtotal)),
            _row(context, 'Discount', '-${currency.format(discountAmount)}'),
            _row(context, 'Tax', currency.format(taxAmount)),
            const Divider(),
            _row(context, 'Total', currency.format(total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
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

/// Bottom-sheet editor for a single [LineItem], with an optional shortcut to
/// prefill description + unit price from the service catalog.
class _LineItemEditor extends StatefulWidget {
  const _LineItemEditor({this.existing, required this.catalog});

  final LineItem? existing;
  final List<ServiceCatalogItem> catalog;

  @override
  State<_LineItemEditor> createState() => _LineItemEditorState();
}

class _LineItemEditorState extends State<_LineItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  String? _selectedCatalogId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _quantityController = TextEditingController(
      text: existing != null ? existing.quantity.toString() : '1',
    );
    _unitPriceController = TextEditingController(
      text: existing != null ? existing.unitPrice.toString() : '0',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  void _applyCatalogItem(String? catalogId) {
    setState(() => _selectedCatalogId = catalogId);
    if (catalogId == null) return;
    final match = widget.catalog.where((c) => c.id == catalogId);
    if (match.isEmpty) return;
    final item = match.first;
    _descriptionController.text = item.description.isNotEmpty ? item.description : item.name;
    _unitPriceController.text = item.defaultRate.toString();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final result = LineItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      description: _descriptionController.text.trim(),
      quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
      unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add Line Item' : 'Edit Line Item',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (widget.catalog.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedCatalogId,
                decoration: const InputDecoration(labelText: 'Pick from catalog (optional)'),
                items: widget.catalog
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: _applyCatalogItem,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Required';
                      return double.tryParse(value.trim()) == null ? 'Invalid' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Required';
                      return double.tryParse(value.trim()) == null ? 'Invalid' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
