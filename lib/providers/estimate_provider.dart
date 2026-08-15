import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/db_helper.dart';
import '../models/estimate.dart';
import '../models/line_item.dart';

class EstimateProvider extends ChangeNotifier {
  EstimateProvider() {
    init();
  }

  final DbHelper _db = DbHelper.instance;
  final Uuid _uuid = const Uuid();

  List<Estimate> _estimates = [];
  bool _isLoading = false;

  List<Estimate> get estimates => List.unmodifiable(_estimates);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _estimates = await _db.getEstimates();
    _isLoading = false;
    notifyListeners();
  }

  Estimate? getById(String id) {
    for (final estimate in _estimates) {
      if (estimate.id == id) return estimate;
    }
    return null;
  }

  Future<Estimate> addEstimate({
    required String clientId,
    required String title,
    required DateTime date,
    List<LineItem>? items,
    double taxRatePercent = 0.0,
    double discountPercent = 0.0,
    String notes = '',
    String status = EstimateStatus.draft,
    String currencyCode = 'USD',
  }) async {
    final estimate = Estimate(
      id: _uuid.v4(),
      clientId: clientId,
      title: title,
      date: date,
      items: items,
      taxRatePercent: taxRatePercent,
      discountPercent: discountPercent,
      notes: notes,
      status: status,
      currencyCode: currencyCode,
    );
    await _db.insertEstimate(estimate);
    _estimates = await _db.getEstimates();
    notifyListeners();
    return estimate;
  }

  Future<void> updateEstimate(Estimate estimate) async {
    await _db.updateEstimate(estimate);
    _estimates = await _db.getEstimates();
    notifyListeners();
  }

  Future<void> deleteEstimate(String id) async {
    await _db.deleteEstimate(id);
    _estimates = await _db.getEstimates();
    notifyListeners();
  }

  String newId() => _uuid.v4();
}
