import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init() {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('products.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Get the executable's directory
      final executablePath = Platform.resolvedExecutable;
      final executableDir = dirname(executablePath);
      
      // Create 'db' folder if it doesn't exist
      final dbDirectory = Directory(join(executableDir, 'db'));
      if (!await dbDirectory.exists()) {
        await dbDirectory.create(recursive: true);
      }
      
      dbPath = join(dbDirectory.path, filePath);
    } else {
      dbPath = join(await getDatabasesPath(), filePath);
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE products (
        id $idType,
        itemNumber $textType,
        itemName $textType,
        rate $realType,
        description $textType,
        hsnCode $textType
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add itemNumber column to existing database
      await db.execute('ALTER TABLE products ADD COLUMN itemNumber TEXT NOT NULL DEFAULT ""');
    }
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    // Sort by itemNumber numerically using CAST
    final result = await db.query(
      'products',
      orderBy: 'CAST(itemNumber AS INTEGER) ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertProductsBatch(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert('products', product.toMap());
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearAllProducts() async {
    final db = await database;
    await db.delete('products');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

