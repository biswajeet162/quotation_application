import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum SyncLogType {
  push,
  pull,
}

class SyncLog {
  final int? id;
  final SyncLogType type;
  final DateTime timestamp;
  final String message;
  final int itemCount;
  final bool success;
  final String? error;

  SyncLog({
    this.id,
    required this.type,
    required this.timestamp,
    required this.message,
    required this.itemCount,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'itemCount': itemCount,
      'success': success ? 1 : 0,
      'error': error,
    };
  }

  factory SyncLog.fromMap(Map<String, dynamic> map) {
    return SyncLog(
      id: map['id'] as int?,
      type: SyncLogType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SyncLogType.pull,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      message: map['message'] as String,
      itemCount: map['itemCount'] as int,
      success: (map['success'] as int) == 1,
      error: map['error'] as String?,
    );
  }
}

class SyncLogsService {
  static final SyncLogsService instance = SyncLogsService._init();
  SyncLogsService._init();

  static Database? _database;
  
  // Callback to notify when a new log is added
  VoidCallback? onLogAdded;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sync_logs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = dirname(executablePath);
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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        message TEXT NOT NULL,
        itemCount INTEGER NOT NULL,
        success INTEGER NOT NULL,
        error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_timestamp ON sync_logs(timestamp DESC)
    ''');
  }

  Future<int> addLog(SyncLog log) async {
    final db = await database;
    final id = await db.insert('sync_logs', log.toMap());
    // Notify listeners that a new log was added
    onLogAdded?.call();
    return id;
  }

  Future<List<SyncLog>> getLogs({
    SyncLogType? type,
    int? limit,
    DateTime? since,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClause += 'type = ?';
      whereArgs.add(type.name);
    }

    if (since != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(since.toIso8601String());
    }

    final result = await db.query(
      'sync_logs',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return result.map((map) => SyncLog.fromMap(map)).toList();
  }

  Future<int> getLogCount({SyncLogType? type}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClause = 'type = ?';
      whereArgs.add(type.name);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_logs${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
      whereArgs.isEmpty ? null : whereArgs,
    );

    return result.first['count'] as int;
  }

  Future<void> clearLogs({SyncLogType? type}) async {
    final db = await database;
    
    if (type != null) {
      await db.delete('sync_logs', where: 'type = ?', whereArgs: [type.name]);
    } else {
      await db.delete('sync_logs');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

