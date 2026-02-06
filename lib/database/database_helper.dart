import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/company.dart';
import '../models/quotation_history.dart';

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
      version: 9,
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
        designation $textType,
        groupName $textType,
        quantity $realType,
        rsp $realType,
        totalLineGrossWeight $realType,
        packQuantity INTEGER NOT NULL,
        packVolume $realType,
        information $textType
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

    await db.execute('''
      CREATE TABLE companies (
        id $idType,
        name $textType,
        address $textType,
        mobile $textType,
        email $textType,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quotations_history (
        id $idType,
        quotationNumber $textType,
        quotationDate TEXT NOT NULL,
        customerName $textType,
        customerAddress $textType,
        customerContact $textType,
        customerEmail $textType,
        items TEXT NOT NULL,
        totalAmount $realType,
        totalGstAmount $realType,
        grandTotal $realType,
        action $textType,
        createdBy $textType,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create default admin user
    await _createDefaultAdmin(db);
    
    // Insert dummy companies data
    await _insertDummyCompanies(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Legacy: previously added itemNumber column – kept for backward compatibility
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN itemNumber TEXT NOT NULL DEFAULT ""',
        );
      } catch (e) {
        // Column might already exist
      }
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
    if (oldVersion < 5) {
      // Add companies table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS companies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          address TEXT NOT NULL,
          mobile TEXT NOT NULL,
          email TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
      // Insert dummy companies data
      await _insertDummyCompanies(db);
    }
    if (oldVersion < 6) {
      // Add quotations_history table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quotations_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quotationNumber TEXT NOT NULL,
          quotationDate TEXT NOT NULL,
          customerName TEXT NOT NULL,
          customerAddress TEXT NOT NULL,
          customerContact TEXT NOT NULL,
          customerEmail TEXT NOT NULL,
          items TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          totalGstAmount REAL NOT NULL,
          grandTotal REAL NOT NULL,
          action TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      // Add createdBy column to quotations_history table
      try {
        // Check if column already exists
        final tableInfo = await db.rawQuery('PRAGMA table_info(quotations_history)');
        final hasCreatedBy = tableInfo.any((col) => col['name'] == 'createdBy');
        
        if (!hasCreatedBy) {
          // SQLite doesn't support NOT NULL with DEFAULT in ALTER TABLE, so add as nullable first
          await db.execute('ALTER TABLE quotations_history ADD COLUMN createdBy TEXT');
          // Update existing records to have a default value
          await db.update('quotations_history', {'createdBy': 'Unknown'}, where: 'createdBy IS NULL');
        }
      } catch (e) {
        // Column might already exist or other error, log but continue
        debugPrint('Error adding createdBy column: $e');
      }
    }

    // Version 8: migrate products table to new schema (designation, group, etc.)
    if (oldVersion < 8) {
      try {
        // Create new table with desired structure
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            designation INTEGER NOT NULL,
            groupName TEXT NOT NULL,
            quantity REAL NOT NULL,
            rsp REAL NOT NULL,
            totalLineGrossWeight REAL NOT NULL,
            packQuantity INTEGER NOT NULL,
            packVolume REAL NOT NULL,
            information TEXT NOT NULL
          )
        ''');

        // Try to migrate existing data as best-effort (map old rate/description/hsnCode)
        final hasOldColumns = await db
            .rawQuery('PRAGMA table_info(products)')
            .then((cols) => cols.any((c) => c['name'] == 'itemName'));

        if (hasOldColumns) {
          final oldProducts = await db.query('products');
          for (final p in oldProducts) {
            final designation =
                int.tryParse((p['itemNumber'] ?? '0').toString()) ?? 0;
            final groupName = ''; // no direct mapping from old schema
            final quantity = 0.0;
            final rsp = (p['rate'] as num?)?.toDouble() ?? 0.0;
            final totalLineGrossWeight = 0.0;
            final packQuantity = 0;
            final packVolume = 0.0;
            final information = (p['itemName'] ?? '').toString();

            await db.insert('products_new', {
              'designation': designation,
              'groupName': groupName,
              'quantity': quantity,
              'rsp': rsp,
              'totalLineGrossWeight': totalLineGrossWeight,
              'packQuantity': packQuantity,
              'packVolume': packVolume,
              'information': information,
            });
          }
        }

        // Replace old table
        await db.execute('DROP TABLE IF EXISTS products');
        await db.execute('ALTER TABLE products_new RENAME TO products');
      } catch (e) {
        debugPrint('Error migrating products table to new schema: $e');
      }
    }

    // Version 9: Convert designation column from INTEGER to TEXT
    if (oldVersion < 9) {
      try {
        // Check current column type
        final tableInfo = await db.rawQuery('PRAGMA table_info(products)');
        final designationColumn = tableInfo.firstWhere(
          (col) => col['name'] == 'designation',
          orElse: () => {},
        );
        
        // If designation is INTEGER, we need to convert it to TEXT
        if (designationColumn.isNotEmpty && designationColumn['type'] == 'INTEGER') {
          // Create new table with TEXT designation
          await db.execute('''
            CREATE TABLE products_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              designation TEXT NOT NULL,
              groupName TEXT NOT NULL,
              quantity REAL NOT NULL,
              rsp REAL NOT NULL,
              totalLineGrossWeight REAL NOT NULL,
              packQuantity INTEGER NOT NULL,
              packVolume REAL NOT NULL,
              information TEXT NOT NULL
            )
          ''');
          
          // Copy data, converting designation from int to string
          await db.execute('''
            INSERT INTO products_new 
            SELECT id, 
                   CAST(designation AS TEXT) as designation,
                   groupName, quantity, rsp, totalLineGrossWeight, 
                   packQuantity, packVolume, information
            FROM products
          ''');
          
          // Drop old table
          await db.execute('DROP TABLE products');
          
          // Rename new table
          await db.execute('ALTER TABLE products_new RENAME TO products');
        }
      } catch (e) {
        debugPrint('Error migrating designation column to TEXT: $e');
        // If migration fails, the fromMap will handle conversion
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

  Future<void> _insertDummyCompanies(Database db) async {
    try {
      // Check if companies table exists and has data
      final existingCompanies = await db.query('companies');
      if (existingCompanies.isNotEmpty) {
        return; // Don't insert if companies already exist
      }

      final dummyCompanies = [
        {
          'name': 'ABC Corporation',
          'address': '123 Business Street, Mumbai, Maharashtra 400001',
          'mobile': '+91 98765 43210',
          'email': 'contact@abccorp.com',
          'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        },
        {
          'name': 'XYZ Industries Ltd',
          'address': '456 Industrial Area, Delhi, Delhi 110001',
          'mobile': '+91 98765 43211',
          'email': 'info@xyzindustries.com',
          'createdAt': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
        },
        {
          'name': 'Tech Solutions Pvt Ltd',
          'address': '789 Tech Park, Bangalore, Karnataka 560001',
          'mobile': '+91 98765 43212',
          'email': 'sales@techsolutions.in',
          'createdAt': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
        },
        {
          'name': 'Global Trading Company',
          'address': '321 Trade Center, Chennai, Tamil Nadu 600001',
          'mobile': '+91 98765 43213',
          'email': 'info@globaltrading.co.in',
          'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        },
        {
          'name': 'Prime Manufacturing Co',
          'address': '654 Factory Road, Pune, Maharashtra 411001',
          'mobile': '+91 98765 43214',
          'email': 'contact@primemanufacturing.com',
          'createdAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        },
      ];

      for (var company in dummyCompanies) {
        await db.insert('companies', company);
      }
    } catch (e) {
      // Companies might already exist or table doesn't exist yet, ignore error
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
    // Query with explicit CAST to ensure designation is always returned as TEXT
    // This handles cases where old INTEGER values might still exist
    final result = await db.rawQuery(
      'SELECT id, CAST(designation AS TEXT) as designation, groupName, quantity, rsp, totalLineGrossWeight, packQuantity, packVolume, information FROM products ORDER BY designation ASC',
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

  // Company management methods
  Future<int> insertCompany(Company company) async {
    final db = await database;
    return await db.insert('companies', company.toMap());
  }

  Future<List<Company>> getAllCompanies() async {
    final db = await database;
    final result = await db.query('companies', orderBy: 'createdAt DESC');
    return result.map((map) => Company.fromMap(map)).toList();
  }

  Future<Company?> getCompanyById(int id) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return Company.fromMap(result.first);
  }

  Future<int> updateCompany(Company company) async {
    final db = await database;
    return await db.update(
      'companies',
      company.toMap(),
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }

  Future<int> deleteCompany(int id) async {
    final db = await database;
    return await db.delete(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Quotation History management methods
  Future<int> insertQuotationHistory(QuotationHistory quotationHistory) async {
    final db = await database;
    try {
      return await db.insert('quotations_history', quotationHistory.toMap());
    } catch (e) {
      // If error is due to missing createdBy column, try to add it and retry
      if (e.toString().contains('createdBy') || e.toString().contains('no such column')) {
        try {
          // Check if column exists
          final tableInfo = await db.rawQuery('PRAGMA table_info(quotations_history)');
          final hasCreatedBy = tableInfo.any((col) => col['name'] == 'createdBy');
          
          if (!hasCreatedBy) {
            await db.execute('ALTER TABLE quotations_history ADD COLUMN createdBy TEXT');
            await db.update('quotations_history', {'createdBy': 'Unknown'}, where: 'createdBy IS NULL');
          }
          // Retry insert
          return await db.insert('quotations_history', quotationHistory.toMap());
        } catch (e2) {
          debugPrint('Error inserting quotation history after migration: $e2');
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<List<QuotationHistory>> getAllQuotationHistory() async {
    final db = await database;
    try {
      // First check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quotations_history'",
      );
      if (tables.isEmpty) {
        // Table doesn't exist, create it
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quotations_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quotationNumber TEXT NOT NULL,
            quotationDate TEXT NOT NULL,
            customerName TEXT NOT NULL,
            customerAddress TEXT NOT NULL,
            customerContact TEXT NOT NULL,
            customerEmail TEXT NOT NULL,
            items TEXT NOT NULL,
            totalAmount REAL NOT NULL,
            totalGstAmount REAL NOT NULL,
            grandTotal REAL NOT NULL,
            action TEXT NOT NULL,
            createdBy TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      }
      
      final result = await db.query(
        'quotations_history',
        orderBy: 'createdAt DESC',
      );
      
      final quotations = <QuotationHistory>[];
      for (var map in result) {
        try {
          quotations.add(QuotationHistory.fromMap(map));
        } catch (e) {
          // Log error but continue processing other items
          print('Error parsing quotation history item: $e');
          print('Item data: $map');
        }
      }
      return quotations;
    } catch (e) {
      print('Error querying quotations_history table: $e');
      rethrow;
    }
  }

  Future<QuotationHistory?> getQuotationHistoryById(int id) async {
    final db = await database;
    final result = await db.query(
      'quotations_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return QuotationHistory.fromMap(result.first);
  }

  Future<List<QuotationHistory>> getQuotationHistoryByNumber(String quotationNumber) async {
    final db = await database;
    final result = await db.query(
      'quotations_history',
      where: 'quotationNumber = ?',
      whereArgs: [quotationNumber],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => QuotationHistory.fromMap(map)).toList();
  }

  Future<int> updateQuotationHistoryAction(int id, String action, {DateTime? updatedAt}) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'action': action,
    };
    
    // Update createdAt timestamp if provided
    if (updatedAt != null) {
      updateData['createdAt'] = updatedAt.toIso8601String();
    }
    
    return await db.update(
      'quotations_history',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteQuotationHistory(int id) async {
    final db = await database;
    return await db.delete(
      'quotations_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

