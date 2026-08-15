import 'dart:convert';

import 'line_item.dart';

/// Simple string-based status enum for [Estimate].
class EstimateStatus {
  static const String draft = 'draft';
  static const String sent = 'sent';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';

  static const List<String> values = [draft, sent, accepted, rejected];
}

class Estimate {
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

  Estimate({
    required this.id,
    required this.clientId,
    required this.title,
    required this.date,
    List<LineItem>? items,
    this.taxRatePercent = 0.0,
    this.discountPercent = 0.0,
    this.notes = '',
    this.status = EstimateStatus.draft,
    this.currencyCode = 'USD',
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
      };

  factory Estimate.fromMap(Map<String, dynamic> map) => Estimate(
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
        status: map['status'] as String? ?? EstimateStatus.draft,
        currencyCode: map['currencyCode'] as String? ?? 'USD',
      );
}
