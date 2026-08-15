import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/db_helper.dart';
import '../models/service_catalog_item.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider() {
    init();
  }

  final DbHelper _db = DbHelper.instance;
  final Uuid _uuid = const Uuid();

  List<ServiceCatalogItem> _items = [];
  bool _isLoading = false;

  List<ServiceCatalogItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _items = await _db.getCatalogItems();
    _isLoading = false;
    notifyListeners();
  }

  ServiceCatalogItem? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<ServiceCatalogItem> addItem({
    required String name,
    String description = '',
    String unit = 'hour',
    double defaultRate = 0.0,
  }) async {
    final item = ServiceCatalogItem(
      id: _uuid.v4(),
      name: name,
      description: description,
      unit: unit,
      defaultRate: defaultRate,
    );
    await _db.insertCatalogItem(item);
    _items = await _db.getCatalogItems();
    notifyListeners();
    return item;
  }

  Future<void> updateItem(ServiceCatalogItem item) async {
    await _db.updateCatalogItem(item);
    _items = await _db.getCatalogItems();
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteCatalogItem(id);
    _items = await _db.getCatalogItems();
    notifyListeners();
  }
}
