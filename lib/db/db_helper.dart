import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/client.dart';
import '../models/estimate.dart';
import '../models/invoice.dart';
import '../models/service_catalog_item.dart';

/// Singleton wrapper around the local sqflite database.
///
/// There are no migrations yet — the schema is created fresh at version 1.
class DbHelper {
  DbHelper._internal();

  static final DbHelper instance = DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final db = await _initDb();
    _database = db;
    return db;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'itmc_estimator.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            company TEXT,
            email TEXT,
            phone TEXT,
            address TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE service_catalog (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            unit TEXT,
            defaultRate REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE estimates (
            id TEXT PRIMARY KEY,
            clientId TEXT NOT NULL,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            items TEXT NOT NULL,
            taxRatePercent REAL NOT NULL,
            discountPercent REAL NOT NULL,
            notes TEXT,
            status TEXT NOT NULL,
            currencyCode TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE invoices (
            id TEXT PRIMARY KEY,
            clientId TEXT NOT NULL,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            items TEXT NOT NULL,
            taxRatePercent REAL NOT NULL,
            discountPercent REAL NOT NULL,
            notes TEXT,
            status TEXT NOT NULL,
            currencyCode TEXT NOT NULL,
            invoiceNumber TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            sourceEstimateId TEXT
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------
  // Clients
  // ---------------------------------------------------------------------

  Future<void> insertClient(Client client) async {
    final db = await database;
    await db.insert(
      'clients',
      client.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Client>> getClients() async {
    final db = await database;
    final rows = await db.query('clients', orderBy: 'name ASC');
    return rows.map(Client.fromMap).toList();
  }

  Future<void> updateClient(Client client) async {
    final db = await database;
    await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Service catalog
  // ---------------------------------------------------------------------

  Future<void> insertCatalogItem(ServiceCatalogItem item) async {
    final db = await database;
    await db.insert(
      'service_catalog',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ServiceCatalogItem>> getCatalogItems() async {
    final db = await database;
    final rows = await db.query('service_catalog', orderBy: 'name ASC');
    return rows.map(ServiceCatalogItem.fromMap).toList();
  }

  Future<void> updateCatalogItem(ServiceCatalogItem item) async {
    final db = await database;
    await db.update(
      'service_catalog',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteCatalogItem(String id) async {
    final db = await database;
    await db.delete('service_catalog', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Estimates
  // ---------------------------------------------------------------------

  Future<void> insertEstimate(Estimate estimate) async {
    final db = await database;
    await db.insert(
      'estimates',
      estimate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Estimate>> getEstimates() async {
    final db = await database;
    final rows = await db.query('estimates', orderBy: 'date DESC');
    return rows.map(Estimate.fromMap).toList();
  }

  Future<void> updateEstimate(Estimate estimate) async {
    final db = await database;
    await db.update(
      'estimates',
      estimate.toMap(),
      where: 'id = ?',
      whereArgs: [estimate.id],
    );
  }

  Future<void> deleteEstimate(String id) async {
    final db = await database;
    await db.delete('estimates', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Invoices
  // ---------------------------------------------------------------------

  Future<void> insertInvoice(Invoice invoice) async {
    final db = await database;
    await db.insert(
      'invoices',
      invoice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final rows = await db.query('invoices', orderBy: 'date DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }
}
