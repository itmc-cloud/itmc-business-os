import 'dart:convert';

import 'line_item.dart';

/// Simple string-based status enum for [Invoice].
class InvoiceStatus {
  static const String draft = 'draft';
  static const String sent = 'sent';
  static const String paid = 'paid';
  static const String overdue = 'overdue';

  static const List<String> values = [draft, sent, paid, overdue];
}

class Invoice {
  final String id;
  String clientId;
  String title;
  DateTime date;
  List<LineItem> items;
  double taxRatePercent;
  double discountPercent;
  String notes;
  String status;
  String currencyCode;
  String invoiceNumber;
  DateTime dueDate;
  String? sourceEstimateId;

  Invoice({
    required this.id,
    required this.clientId,
    required this.title,
    required this.date,
    List<LineItem>? items,
    this.taxRatePercent = 0.0,
    this.discountPercent = 0.0,
    this.notes = '',
    this.status = InvoiceStatus.draft,
    this.currencyCode = 'USD',
    required this.invoiceNumber,
    required this.dueDate,
    this.sourceEstimateId,
  }) : items = items ?? [];

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  double get discountAmount => subtotal * (discountPercent / 100.0);

  double get taxAmount => (subtotal - discountAmount) * (taxRatePercent / 100.0);

  double get total => subtotal - discountAmount + taxAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientId': clientId,
        'title': title,
        'date': date.toIso8601String(),
        'items': jsonEncode(items.map((i) => i.toJson()).toList()),
        'taxRatePercent': taxRatePercent,
        'discountPercent': discountPercent,
        'notes': notes,
        'status': status,
        'currencyCode': currencyCode,
        'invoiceNumber': invoiceNumber,
        'dueDate': dueDate.toIso8601String(),
        'sourceEstimateId': sourceEstimateId,
      };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as String,
        clientId: map['clientId'] as String,
        title: map['title'] as String,
        date: DateTime.parse(map['date'] as String),
        items: (jsonDecode(map['items'] as String) as List<dynamic>)
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxRatePercent: (map['taxRatePercent'] as num?)?.toDouble() ?? 0.0,
        discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
        notes: map['notes'] as String? ?? '',
        status: map['status'] as String? ?? InvoiceStatus.draft,
        currencyCode: map['currencyCode'] as String? ?? 'USD',
        invoiceNumber: map['invoiceNumber'] as String,
        dueDate: DateTime.parse(map['dueDate'] as String),
        sourceEstimateId: map['sourceEstimateId'] as String?,
      );
}
