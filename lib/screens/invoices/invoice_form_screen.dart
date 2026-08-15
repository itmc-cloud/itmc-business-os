import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/invoice.dart';
import '../../models/line_item.dart';
import '../../models/service_catalog_item.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/invoice_provider.dart';

/// Add/edit form for an [Invoice]. Pass an existing [invoice] to edit it,
/// or leave null to create a new one.
class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key, this.invoice});

  final Invoice? invoice;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _taxController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  String? _clientId;
  late DateTime _date;
  late DateTime _dueDate;
  late String _status;
  late List<LineItem> _items;

  bool get _isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _titleController = TextEditingController(text: invoice?.title ?? '');
    _invoiceNumberController = TextEditingController(
      text: invoice?.invoiceNumber ?? InvoiceProvider.generateInvoiceNumber(),
    );
    _taxController = TextEditingController(
      text: invoice != null ? invoice.taxRatePercent.toString() : '0',
    );
    _discountController = TextEditingController(
      text: invoice != null ? invoice.discountPercent.toString() : '0',
    );
    _notesController = TextEditingController(text: invoice?.notes ?? '');
    _clientId = invoice?.clientId;
    _date = invoice?.date ?? DateTime.now();
    _dueDate = invoice?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _status = invoice?.status ?? InvoiceStatus.draft;
    _items = invoice != null
        ? invoice.items
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
    _invoiceNumberController.dispose();
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

  Future<void> _pickDate({required bool isDueDate}) async {
    final initial = isDueDate ? _dueDate : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  Future<void> _addOrEditItem({LineItem? existing}) async {
    final catalog = context.read<CatalogProvider>().items;
    final result = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InvoiceLineItemEditor(existing: existing, catalog: catalog),
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

    final invoiceProvider = context.read<InvoiceProvider>();

    if (_isEditing) {
      final invoice = widget.invoice!
        ..clientId = _clientId!
        ..title = _titleController.text.trim()
        ..invoiceNumber = _invoiceNumberController.text.trim()
        ..date = _date
        ..dueDate = _dueDate
        ..items = _items
        ..taxRatePercent = _taxPercent()
        ..discountPercent = _discountPercent()
        ..notes = _notesController.text.trim()
        ..status = _status;
      await invoiceProvider.updateInvoice(invoice);
    } else {
      await invoiceProvider.addInvoice(
        clientId: _clientId!,
        title: _titleController.text.trim(),
        date: _date,
        dueDate: _dueDate,
        invoiceNumber: _invoiceNumberController.text.trim(),
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
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
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
              controller: _invoiceNumberController,
              decoration: const InputDecoration(labelText: 'Invoice Number'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
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
              onTap: () => _pickDate(isDueDate: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text(DateFormat.yMMMd().format(_dueDate)),
              trailing: const Icon(Icons.event),
              onTap: () => _pickDate(isDueDate: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: InvoiceStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            if (widget.invoice?.sourceEstimateId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Generated from estimate ${widget.invoice!.sourceEstimateId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(context, 'Subtotal', currency.format(_subtotal)),
                    _row(context, 'Discount', '-${currency.format(_discountAmount)}'),
                    _row(context, 'Tax', currency.format(_taxAmount)),
                    const Divider(),
                    _row(context, 'Total', currency.format(_total), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save Invoice'),
            ),
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
class _InvoiceLineItemEditor extends StatefulWidget {
  const _InvoiceLineItemEditor({this.existing, required this.catalog});

  final LineItem? existing;
  final List<ServiceCatalogItem> catalog;

  @override
  State<_InvoiceLineItemEditor> createState() => _InvoiceLineItemEditorState();
}

class _InvoiceLineItemEditorState extends State<_InvoiceLineItemEditor> {
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
