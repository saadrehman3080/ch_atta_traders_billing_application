import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:ch_atta_traders_billing_application/data/models/shop.dart';

/// Singleton database helper for managing the shops SQLite database.
///
/// Handles database creation, CSV data seeding, and all shop-related queries.
/// The shops data is seeded from a bundled CSV asset on first launch.
class ShopDatabaseHelper {
  // ========== Singleton Pattern ==========
  ShopDatabaseHelper._internal();
  static final ShopDatabaseHelper _instance = ShopDatabaseHelper._internal();
  static ShopDatabaseHelper get instance => _instance;

  // ========== Database Constants ==========
  static const String _databaseName = 'ch_atta_shops.db';
  static const int _databaseVersion = 1;
  static const String tableShops = 'shops';

  // Column names
  static const String colOutletCode = 'outlet_code';
  static const String colOutletName = 'outlet_name';
  static const String colOutletAddress = 'outlet_address';
  static const String colTown = 'town';
  static const String colRouteTitle = 'route_title';
  static const String colOwner = 'owner';
  static const String colPhone = 'phone';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';

  // ========== Private Members ==========
  Database? _database;
  Future<Database>? _initFuture;

  /// Returns the database instance, creating it if necessary.
  Future<Database> get database async {
    _database ??= await (_initFuture ??= _initDatabase());
    return _database!;
  }

  /// Initializes the SQLite database.
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Creates the shops table on first database creation.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableShops (
        $colOutletCode TEXT PRIMARY KEY,
        $colOutletName TEXT NOT NULL,
        $colOutletAddress TEXT NOT NULL,
        $colTown TEXT NOT NULL,
        $colRouteTitle TEXT NOT NULL,
        $colOwner TEXT,
        $colPhone TEXT,
        $colLatitude REAL,
        $colLongitude REAL
      )
    ''');

    // Create index on route_title for faster filtering
    await db.execute(
      'CREATE INDEX idx_route_title ON $tableShops ($colRouteTitle)',
    );

    // Create index on outlet_name for faster searching
    await db.execute(
      'CREATE INDEX idx_outlet_name ON $tableShops ($colOutletName)',
    );
  }

  /// Seeds the database with shop data from the bundled CSV file.
  ///
  /// This should be called once during app initialization.
  /// If the database already has data, this method does nothing.
  Future<void> seedFromCsv() async {
    final db = await database;

    // Check if data already exists
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableShops'),
    );
    if (count != null && count > 0) {
      debugPrint('Shop database already seeded with $count shops');
      return;
    }

    try {
      final csvString = await rootBundle.loadString(
        'CHAUDHARY_ATTA_TRADERS_Shops.csv',
      );
      final lines = csvString.split('\n');

      if (lines.isEmpty) {
        debugPrint('CSV file is empty');
        return;
      }

      // Skip header row
      final batch = db.batch();
      int insertCount = 0;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final shop = _parseCsvLine(line);
          if (shop != null) {
            batch.insert(
              tableShops,
              shop.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            insertCount++;
          }
        } catch (e) {
          debugPrint('Error parsing CSV line $i: $e');
        }
      }

      await batch.commit(noResult: true);
      debugPrint('Successfully seeded $insertCount shops into database');
    } catch (e) {
      debugPrint('Error seeding shop database: $e');
      rethrow;
    }
  }

  /// Parses a single CSV line into a [Shop] object.
  ///
  /// CSV columns: Outlet Code, Outlet Name, Outlet Address, Town,
  /// Route Title, Head Channel, Sub Channel, Segment Name, Owner,
  /// Cell#1, Latitude, Longitude
  Shop? _parseCsvLine(String line) {
    // Handle CSV fields that may contain commas within quotes
    final fields = _splitCsvLine(line);
    if (fields.length < 12) return null;

    final outletCode = fields[0].trim();
    final outletName = fields[1].trim();
    final outletAddress = fields[2].trim();
    final town = fields[3].trim();
    final routeTitle = fields[4].trim();
    // Skip fields[5] (Head Channel), fields[6] (Sub Channel), fields[7] (Segment Name)
    final owner = fields[8].trim();
    final phone = fields[9].trim();
    final latitude = double.tryParse(fields[10].trim());
    final longitude = double.tryParse(fields[11].trim());

    if (outletCode.isEmpty || outletName.isEmpty) return null;

    return Shop(
      outletCode: outletCode,
      outletName: outletName,
      outletAddress: outletAddress,
      town: town,
      routeTitle: routeTitle,
      owner: owner,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Splits a CSV line respecting quoted fields.
  List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());
    return fields;
  }

  // ========== Query Methods ==========

  /// Returns all shops for a given route title.
  ///
  /// [routeTitle] should be like "KALLAR SYEDAN-1", "KALLAR SYEDAN-2", etc.
  Future<List<Shop>> getShopsByRoute(String routeTitle) async {
    final db = await database;
    final maps = await db.query(
      tableShops,
      where: '$colRouteTitle = ?',
      whereArgs: [routeTitle],
      orderBy: colOutletName,
    );
    return maps.map((map) => Shop.fromMap(map)).toList();
  }

  /// Searches shops by name within a specific route.
  ///
  /// Returns shops whose name contains [query] (case-insensitive)
  /// filtered by [routeTitle].
  Future<List<Shop>> searchShops(String query, String routeTitle) async {
    final db = await database;
    final escapedQuery = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final maps = await db.query(
      tableShops,
      where: '$colRouteTitle = ? AND $colOutletName LIKE ? ESCAPE \'\\\'',
      whereArgs: [routeTitle, '%$escapedQuery%'],
      orderBy: colOutletName,
    );
    return maps.map((map) => Shop.fromMap(map)).toList();
  }

  /// Returns all unique route titles from the database.
  Future<List<String>> getRouteTitles() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT $colRouteTitle FROM $tableShops ORDER BY $colRouteTitle',
    );
    return maps.map((m) => m[colRouteTitle] as String).toList();
  }

  /// Returns the total count of shops in the database.
  Future<int> getShopCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableShops'),
        ) ??
        0;
  }

  /// Returns a single shop by outlet code.
  Future<Shop?> getShopByCode(String outletCode) async {
    final db = await database;
    final maps = await db.query(
      tableShops,
      where: '$colOutletCode = ?',
      whereArgs: [outletCode],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Shop.fromMap(maps.first);
  }

  /// Closes the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
