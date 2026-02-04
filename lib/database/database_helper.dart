import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/user.dart';

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
      version: 4,
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

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        email $textType UNIQUE,
        password $textType,
        role $textType,
        name $textType,
        mobileNumber $textType,
        createdBy TEXT,
        createdAt TEXT NOT NULL,
        lastLoginTime TEXT
      )
    ''');

    // Create default admin user
    await _createDefaultAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add itemNumber column to existing database
      await db.execute('ALTER TABLE products ADD COLUMN itemNumber TEXT NOT NULL DEFAULT ""');
    }
    if (oldVersion < 3) {
      // Add users table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          role TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
      // Create default admin user if it doesn't exist
      final adminExists = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: ['admin@gmail.com'],
      );
      if (adminExists.isEmpty) {
        await _createDefaultAdmin(db);
      }
    }
    if (oldVersion < 4) {
      // Add new columns to users table
      try {
        await db.execute('ALTER TABLE users ADD COLUMN name TEXT NOT NULL DEFAULT ""');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE users ADD COLUMN mobileNumber TEXT NOT NULL DEFAULT ""');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE users ADD COLUMN createdBy TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE users ADD COLUMN lastLoginTime TEXT');
      } catch (e) {
        // Column might already exist
      }
      // Update all existing users to have default values for name and mobileNumber
      final allUsers = await db.query('users');
      for (var user in allUsers) {
        final userId = user['id'] as int;
        final email = user['email'] as String;
        final updateData = <String, dynamic>{};
        
        if (user['name'] == null || (user['name'] as String?)?.isEmpty == true) {
          updateData['name'] = email == 'admin@gmail.com' ? 'Administrator' : '';
        }
        if (user['mobileNumber'] == null || (user['mobileNumber'] as String?)?.isEmpty == true) {
          updateData['mobileNumber'] = '';
        }
        
        if (updateData.isNotEmpty) {
          await db.update(
            'users',
            updateData,
            where: 'id = ?',
            whereArgs: [userId],
          );
        }
      }
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    try {
      final adminPassword = _hashPassword('Admin');
      await db.insert('users', {
        'email': 'admin@gmail.com',
        'password': adminPassword,
        'role': 'admin',
        'name': 'Administrator',
        'mobileNumber': '',
        'createdBy': null,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLoginTime': null,
      });
    } catch (e) {
      // Admin user might already exist, ignore error
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

  // User management methods
  Future<User?> authenticateUser(String email, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );

    if (result.isEmpty) {
      return null;
    }

    // Update last login time
    final userId = result.first['id'] as int;
    await db.update(
      'users',
      {'lastLoginTime': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );

    // Fetch updated user
    final updatedResult = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    return User.fromMap(updatedResult.first);
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (result.isEmpty) {
      return null;
    }

    return User.fromMap(result.first);
  }

  Future<int> createUser(
    String email,
    String password,
    String role,
    String name,
    String mobileNumber,
    String? createdBy,
  ) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    return await db.insert('users', {
      'email': email,
      'password': hashedPassword,
      'role': role,
      'name': name,
      'mobileNumber': mobileNumber,
      'createdBy': createdBy,
      'createdAt': DateTime.now().toIso8601String(),
      'lastLoginTime': null,
    });
  }

  Future<int> updateUserPassword(int userId, String newPassword) async {
    final db = await database;
    final hashedPassword = _hashPassword(newPassword);
    return await db.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'createdAt DESC');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    // Prevent deleting the default admin
    final user = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (user.isNotEmpty && user.first['email'] == 'admin@gmail.com') {
      throw Exception('Cannot delete the default admin user');
    }
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

