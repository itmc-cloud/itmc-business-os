import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/db_helper.dart';
import '../models/client.dart';

class ClientProvider extends ChangeNotifier {
  ClientProvider() {
    init();
  }

  final DbHelper _db = DbHelper.instance;
  final Uuid _uuid = const Uuid();

  List<Client> _clients = [];
  bool _isLoading = false;

  List<Client> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    _clients = await _db.getClients();
    _isLoading = false;
    notifyListeners();
  }

  Client? getById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<Client> addClient({
    required String name,
    String company = '',
    String email = '',
    String phone = '',
    String address = '',
  }) async {
    final client = Client(
      id: _uuid.v4(),
      name: name,
      company: company,
      email: email,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
    );
    await _db.insertClient(client);
    _clients = await _db.getClients();
    notifyListeners();
    return client;
  }

  Future<void> updateClient(Client client) async {
    await _db.updateClient(client);
    _clients = await _db.getClients();
    notifyListeners();
  }

  Future<void> deleteClient(String id) async {
    await _db.deleteClient(id);
    _clients = await _db.getClients();
    notifyListeners();
  }
}
