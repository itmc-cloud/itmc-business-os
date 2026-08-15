import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/db_helper.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';

class InvoiceProvider extends ChangeNotifier {
  InvoiceProvider() {
    init();
  }

  final DbHelper _db = DbHelper.instance;
  final Uuid _uuid = const Uuid();

  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => List.unmodifiable(_invoices);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _invoices = await _db.getInvoices();
    _isLoading = false;
    notifyListeners();
  }

  Invoice? getById(String id) {
    for (final invoice in _invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

  Future<Invoice> addInvoice({
    required String clientId,
    required String title,
    required DateTime date,
    required DateTime dueDate,
    String? invoiceNumber,
    List<LineItem>? items,
    double taxRatePercent = 0.0,
    double discountPercent = 0.0,
    String notes = '',
    String status = InvoiceStatus.draft,
    String currencyCode = 'USD',
    String? sourceEstimateId,
  }) async {
    final invoice = Invoice(
      id: _uuid.v4(),
      clientId: clientId,
      title: title,
      date: date,
      dueDate: dueDate,
      invoiceNumber: invoiceNumber ?? generateInvoiceNumber(),
      items: items,
      taxRatePercent: taxRatePercent,
      discountPercent: discountPercent,
      notes: notes,
      status: status,
      currencyCode: currencyCode,
      sourceEstimateId: sourceEstimateId,
    );
    await _db.insertInvoice(invoice);
    _invoices = await _db.getInvoices();
    notifyListeners();
    return invoice;
  }

  Future<void> saveInvoice(Invoice invoice) async {
    await _db.insertInvoice(invoice);
    _invoices = await _db.getInvoices();
    notifyListeners();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _db.updateInvoice(invoice);
    _invoices = await _db.getInvoices();
    notifyListeners();
  }

  Future<void> deleteInvoice(String id) async {
    await _db.deleteInvoice(id);
    _invoices = await _db.getInvoices();
    notifyListeners();
  }

  String newId() => _uuid.v4();

  static String generateInvoiceNumber() =>
      'INV-${DateTime.now().millisecondsSinceEpoch}';
}
