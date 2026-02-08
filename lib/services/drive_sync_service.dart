import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/company.dart';
import '../models/quotation_history.dart';
import 'google_drive_service.dart';
import 'google_auth_service.dart';
import 'authenticated_http_client.dart';

class DriveSyncService {
  static final DriveSyncService instance = DriveSyncService._init();
  DriveSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final GoogleDriveService _driveService = GoogleDriveService.instance;

  /// Push only - uploads pending local changes to Drive
  Future<SyncResult> pushOnly({bool forceFullSync = false}) async {
    final result = SyncResult();

    try {
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        result.errors.add('Not authenticated with Google');
        return result;
      }

      result.usersSynced = await _syncUsers(null, forceFullSync);
      result.companiesSynced = await _syncCompanies(null, forceFullSync);
      result.quotationsSynced = await _syncQuotations(null, forceFullSync);
      result.myCompanySynced = await _syncMyCompany(null, forceFullSync);

      result.success = true;
    } catch (e) {
      result.errors.add('Push failed: $e');
    }

    return result;
  }

  /// Pull only - downloads changes from Drive to local DB
  Future<SyncResult> pullOnly({bool forceFullSync = false}) async {
    final result = SyncResult();

    try {
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        result.errors.add('Not authenticated with Google');
        return result;
      }

      // Check if this is first-time setup (empty database)
      // If so, force full sync to download all data
      if (!forceFullSync && await _isFirstTimeSetup()) {
        debugPrint('First-time setup detected - forcing full sync');
        forceFullSync = true;
      }

      final lastSync = await _getLastSyncTime();
      final syncStartTime = DateTime.now();

      await _downloadAndMergeRemoteChanges(lastSync, forceFullSync, result);

      await _updateLastSyncTime(syncStartTime);
      await _logSync(result, syncStartTime);

      result.success = true;
    } catch (e) {
      result.errors.add('Pull failed: $e');
      await _logSync(result, DateTime.now());
    }

    return result;
  }

  /// Check if this is a first-time setup (database is mostly empty)
  /// Returns true if database has only default admin user and no other data
  Future<bool> _isFirstTimeSetup() async {
    try {
      final db = await _db.database;
      
      // Check if users table has more than just the default admin
      final users = await db.query('users');
      final hasOnlyDefaultAdmin = users.length <= 1 && 
          (users.isEmpty || users.first['email'] == 'admin@gmail.com');
      
      // Check if companies table is empty or has only dummy data
      final companies = await db.query('companies');
      final hasNoRealCompanies = companies.isEmpty;
      
      // Check if quotations_history is empty
      final quotations = await db.query('quotations_history');
      final hasNoQuotations = quotations.isEmpty;
      
      // Check if my_company is not set
      final myCompany = await _db.getMyCompany();
      final hasNoMyCompany = myCompany == null;
      
      // First-time setup if: only default admin exists, no companies, no quotations, no my_company
      return hasOnlyDefaultAdmin && hasNoRealCompanies && hasNoQuotations && hasNoMyCompany;
    } catch (e) {
      debugPrint('Error checking first-time setup: $e');
      // If we can't check, assume it's not first-time to be safe
      return false;
    }
  }

  /// Full sync - both push and pull
  Future<SyncResult> syncAll({bool forceFullSync = false}) async {
    final result = SyncResult();

    try {
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        result.errors.add('Not authenticated with Google');
        return result;
      }

      final lastSync = await _getLastSyncTime();
      final syncStartTime = DateTime.now();

      // First push local changes
      result.usersSynced = await _syncUsers(lastSync, forceFullSync);
      result.companiesSynced = await _syncCompanies(lastSync, forceFullSync);
      result.quotationsSynced = await _syncQuotations(lastSync, forceFullSync);
      result.myCompanySynced = await _syncMyCompany(lastSync, forceFullSync);

      // Then pull remote changes
      await _downloadAndMergeRemoteChanges(lastSync, forceFullSync, result);

      await _updateLastSyncTime(syncStartTime);
      await _logSync(result, syncStartTime);

      result.success = true;
    } catch (e) {
      result.errors.add('Sync failed: $e');
      await _logSync(result, DateTime.now());
    }

    return result;
  }

  Future<int> _syncUsers(DateTime? lastSync, bool forceFullSync) async {
    final db = await _db.database;
    int synced = 0;

    final pendingUsers = await db.query(
      'users',
      where: forceFullSync ? null : "sync_status = 'PENDING'",
    );

    for (final userMap in pendingUsers) {
      try {
        final user = User.fromMap(userMap);
        final fileName = 'user_${user.id}.json';
        final json = _userToJson(userMap);

        final existingFileId = await _driveService.findFileByName(
          fileName,
          'users',
        );

        await _driveService.uploadFile(
          fileName: fileName,
          content: json,
          folderName: 'users',
          fileId: existingFileId,
        );

        await db.update(
          'users',
          {
            'sync_status': 'SYNCED',
            // Don't update updatedAt - preserve original timestamp
          },
          where: 'id = ?',
          whereArgs: [user.id],
        );

        synced++;
      } catch (e) {
        debugPrint('Error syncing user ${userMap['id']}: $e');
      }
    }

    return synced;
  }

  Future<int> _syncCompanies(DateTime? lastSync, bool forceFullSync) async {
    final db = await _db.database;
    int synced = 0;

    final pendingCompanies = await db.query(
      'companies',
      where: forceFullSync ? null : "sync_status = 'PENDING'",
    );

    for (final companyMap in pendingCompanies) {
      try {
        final company = Company.fromMap(companyMap);
        final fileName = 'company_${company.id}.json';
        final json = _companyToJson(companyMap);

        final existingFileId = await _driveService.findFileByName(
          fileName,
          'companies',
        );

        await _driveService.uploadFile(
          fileName: fileName,
          content: json,
          folderName: 'companies',
          fileId: existingFileId,
        );

        await db.update(
          'companies',
          {
            'sync_status': 'SYNCED',
            // Don't update updatedAt - preserve original timestamp
          },
          where: 'id = ?',
          whereArgs: [company.id],
        );

        synced++;
      } catch (e) {
        debugPrint('Error syncing company ${companyMap['id']}: $e');
      }
    }

    return synced;
  }

  Future<int> _syncQuotations(DateTime? lastSync, bool forceFullSync) async {
    final db = await _db.database;
    int synced = 0;

    final pendingQuotations = await db.query(
      'quotations_history',
      where: forceFullSync ? null : "sync_status = 'PENDING'",
    );

    for (final quotationMap in pendingQuotations) {
      try {
        final quotation = QuotationHistory.fromMap(quotationMap);
        final year = quotation.quotationDate.year.toString();
        final fileName = '${quotation.quotationNumber}.json';
        final json = _quotationToJson(quotationMap);

        final quotationsFolderId = await _driveService.getFolderId('quotations');
        final yearFolderId = await _driveService.findOrCreateFolder(
          year,
          quotationsFolderId,
        );

        await _syncQuotationFile(json, fileName, yearFolderId);

        await db.update(
          'quotations_history',
          {
            'sync_status': 'SYNCED',
            // Don't update updatedAt - preserve original timestamp
          },
          where: 'id = ?',
          whereArgs: [quotation.id],
        );

        synced++;
      } catch (e) {
        debugPrint('Error syncing quotation ${quotationMap['id']}: $e');
      }
    }

    return synced;
  }

  Future<void> _syncQuotationFile(
    String json,
    String fileName,
    String folderId,
  ) async {
    final query = "name='$fileName' and '$folderId' in parents and trashed=false";
    if (!await GoogleAuthService.instance.loadStoredTokens()) {
      throw Exception('Not authenticated');
    }

    final baseClient = http.Client();
    final authClient = AuthenticatedHttpClient(baseClient);

    final driveApi = drive.DriveApi(authClient);
    final response = await driveApi.files.list(
      q: query,
      spaces: 'drive',
    );

    String? fileId;
    if (response.files != null && response.files!.isNotEmpty) {
      fileId = response.files!.first.id;
    }

    final fileMetadata = drive.File();
    fileMetadata.name = fileName;

    final media = drive.Media(
      Stream.fromIterable([utf8.encode(json)]),
      utf8.encode(json).length,
      contentType: 'application/json',
    );

    if (fileId != null) {
      // Don't set parents when updating - it's not writable in update requests
      await driveApi.files.update(fileMetadata, fileId, uploadMedia: media);
    } else {
      // Only set parents when creating a new file
      fileMetadata.parents = [folderId];
      await driveApi.files.create(fileMetadata, uploadMedia: media);
    }
  }

  Future<int> _syncMyCompany(DateTime? lastSync, bool forceFullSync) async {
    final db = await _db.database;
    final myCompany = await _db.getMyCompany();

    if (myCompany == null) {
      return 0;
    }

    final syncStatus = myCompany['sync_status'] as String? ?? 'SYNCED';
    if (!forceFullSync && syncStatus != 'PENDING') {
      return 0;
    }

    try {
      final fileName = 'my_company.json';
      final json = _myCompanyToJson(myCompany);

      final existingFileId = await _driveService.findFileByName(
        fileName,
        'my_company',
      );

      await _driveService.uploadFile(
        fileName: fileName,
        content: json,
        folderName: 'my_company',
        fileId: existingFileId,
      );

      await db.update(
        'my_company',
        {
          'sync_status': 'SYNCED',
          // Don't update updatedAt - preserve original timestamp
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      return 1;
    } catch (e) {
      debugPrint('Error syncing my_company: $e');
      return 0;
    }
  }

  Future<void> _downloadAndMergeRemoteChanges(
    DateTime? lastSync,
    bool forceFullSync,
    SyncResult result,
  ) async {
    await _downloadUsers(lastSync, forceFullSync, result);
    await _downloadCompanies(lastSync, forceFullSync, result);
    await _downloadQuotations(lastSync, forceFullSync, result);
    await _downloadMyCompany(lastSync, forceFullSync, result);
  }

  Future<void> _downloadUsers(
    DateTime? lastSync,
    bool forceFullSync,
    SyncResult result,
  ) async {
    try {
      final files = await _driveService.listFilesInFolder(
        'users',
        modifiedAfter: forceFullSync ? null : lastSync,
      );

      final db = await _db.database;

      for (final file in files) {
        try {
          final content = await _driveService.downloadFile(file.id!);
          final data = jsonDecode(content) as Map<String, dynamic>;

          final localUser = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [data['id']],
          );

          if (localUser.isEmpty) {
            await _insertUserFromDrive(data);
            result.usersDownloaded++;
          } else {
            // Use file's modifiedTime from Google Drive for conflict resolution
            final fileModifiedTime = file.modifiedTime != null 
                ? DateTime.parse(file.modifiedTime!.toIso8601String())
                : null;
            final merged = await _resolveConflict(
              localUser.first, 
              data, 
              'users',
              fileModifiedTime: fileModifiedTime,
            );
            if (merged != null) {
              await db.update('users', merged, where: 'id = ?', whereArgs: [data['id']]);
              result.usersMerged++;
            }
          }
        } catch (e) {
          debugPrint('Error downloading user ${file.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error downloading users: $e');
    }
  }

  Future<void> _downloadCompanies(
    DateTime? lastSync,
    bool forceFullSync,
    SyncResult result,
  ) async {
    try {
      final files = await _driveService.listFilesInFolder(
        'companies',
        modifiedAfter: forceFullSync ? null : lastSync,
      );

      final db = await _db.database;

      for (final file in files) {
        try {
          final content = await _driveService.downloadFile(file.id!);
          final data = jsonDecode(content) as Map<String, dynamic>;

          final localCompany = await db.query(
            'companies',
            where: 'id = ?',
            whereArgs: [data['id']],
          );

          if (localCompany.isEmpty) {
            await _insertCompanyFromDrive(data);
            result.companiesDownloaded++;
          } else {
            // Use file's modifiedTime from Google Drive for conflict resolution
            final fileModifiedTime = file.modifiedTime != null 
                ? DateTime.parse(file.modifiedTime!.toIso8601String())
                : null;
            final merged = await _resolveConflict(
              localCompany.first, 
              data, 
              'companies',
              fileModifiedTime: fileModifiedTime,
            );
            if (merged != null) {
              await db.update('companies', merged, where: 'id = ?', whereArgs: [data['id']]);
              result.companiesMerged++;
            }
          }
        } catch (e) {
          debugPrint('Error downloading company ${file.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error downloading companies: $e');
    }
  }

  Future<void> _downloadQuotations(
    DateTime? lastSync,
    bool forceFullSync,
    SyncResult result,
  ) async {
    try {
      final quotationsFolderId = await _driveService.getFolderId('quotations');
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        return;
      }

      final baseClient = http.Client();
      final authClient = AuthenticatedHttpClient(baseClient);

      final driveApi = drive.DriveApi(authClient);

      String query = "'$quotationsFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final yearFolders = await driveApi.files.list(
        q: query,
        spaces: 'drive',
      );

      final db = await _db.database;

      for (final yearFolder in yearFolders.files ?? []) {
        String fileQuery = "'${yearFolder.id}' in parents and trashed=false";
        if (!forceFullSync && lastSync != null) {
          // Subtract 2 hours buffer to account for clock differences and ensure we don't miss files
          // that were uploaded just before the last sync time
          final bufferTime = lastSync.subtract(const Duration(hours: 2));
          final timeStr = bufferTime.toUtc().toIso8601String();
          fileQuery += " and modifiedTime > '$timeStr'";
        }

        final files = await driveApi.files.list(
          q: fileQuery,
          spaces: 'drive',
        );

        for (final file in files.files ?? []) {
          try {
            final content = await _driveService.downloadFile(file.id!);
            final data = jsonDecode(content) as Map<String, dynamic>;

            // Check by ID first (primary key) - this is the most reliable check
            final localQuotationById = await db.query(
              'quotations_history',
              where: 'id = ?',
              whereArgs: [data['id']],
            );

            if (localQuotationById.isNotEmpty) {
              // Quotation exists with this ID - resolve conflict and update
              final fileModifiedTime = file.modifiedTime != null 
                  ? DateTime.parse(file.modifiedTime!.toIso8601String())
                  : null;
              final merged = await _resolveConflict(
                localQuotationById.first, 
                data, 
                'quotations_history',
                fileModifiedTime: fileModifiedTime,
              );
              if (merged != null) {
                await db.update(
                  'quotations_history',
                  merged,
                  where: 'id = ?',
                  whereArgs: [data['id']],
                );
                result.quotationsMerged++;
              }
            } else {
              // Check by quotationNumber as fallback (in case ID changed but quotationNumber is same)
              final localQuotationByNumber = await db.query(
                'quotations_history',
                where: 'quotationNumber = ?',
                whereArgs: [data['quotationNumber']],
              );

              if (localQuotationByNumber.isNotEmpty) {
                // Quotation exists with same quotationNumber but different ID
                // This is a conflict - resolve it
                final fileModifiedTime = file.modifiedTime != null 
                    ? DateTime.parse(file.modifiedTime!.toIso8601String())
                    : null;
                final merged = await _resolveConflict(
                  localQuotationByNumber.first, 
                  data, 
                  'quotations_history',
                  fileModifiedTime: fileModifiedTime,
                );
                if (merged != null) {
                  // Update the existing record (keeping its original ID)
                  await db.update(
                    'quotations_history',
                    merged,
                    where: 'quotationNumber = ?',
                    whereArgs: [data['quotationNumber']],
                  );
                  result.quotationsMerged++;
                }
              } else {
                // New quotation - insert it
                await _insertQuotationFromDrive(data);
                result.quotationsDownloaded++;
              }
            }
          } catch (e) {
            debugPrint('Error downloading quotation ${file.name}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading quotations: $e');
    }
  }

  Future<void> _downloadMyCompany(
    DateTime? lastSync,
    bool forceFullSync,
    SyncResult result,
  ) async {
    try {
      final fileId = await _driveService.findFileByName('my_company.json', 'my_company');
      if (fileId == null) {
        return;
      }

      // Get file metadata to check modifiedTime
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        return;
      }

      final baseClient = http.Client();
      final authClient = AuthenticatedHttpClient(baseClient);
      final driveApi = drive.DriveApi(authClient);
      final fileMetadata = await driveApi.files.get(fileId) as drive.File;

      final content = await _driveService.downloadFile(fileId);
      final data = jsonDecode(content) as Map<String, dynamic>;

      final db = await _db.database;
      final local = await _db.getMyCompany();

      if (local == null) {
        await _insertMyCompanyFromDrive(data);
        result.myCompanyDownloaded = true;
      } else {
        // Use file's modifiedTime from Google Drive for conflict resolution
        final fileModifiedTime = fileMetadata.modifiedTime != null 
            ? DateTime.parse(fileMetadata.modifiedTime!.toIso8601String())
            : null;
        final merged = await _resolveConflict(
          local, 
          data, 
          'my_company',
          fileModifiedTime: fileModifiedTime,
        );
        if (merged != null) {
          await db.update('my_company', merged, where: 'id = ?', whereArgs: [1]);
          result.myCompanyMerged = true;
        }
      }
    } catch (e) {
      debugPrint('Error downloading my_company: $e');
    }
  }

  Future<Map<String, dynamic>?> _resolveConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    String tableName, {
    DateTime? fileModifiedTime,
  }) async {
    final localVersion = local['version'] as int? ?? 1;
    final remoteVersion = remote['version'] as int? ?? 1;
    final localUpdatedAt = local['updatedAt'] as String? ?? local['createdAt'] as String? ?? '';
    final remoteUpdatedAt = remote['updatedAt'] as String? ?? remote['createdAt'] as String? ?? '';

    // First, check if data is actually different to avoid unnecessary updates
    if (_isDataIdentical(local, remote, tableName)) {
      // Data is identical, no need to update
      return null;
    }

    // If fileModifiedTime is provided (from Google Drive), use it for conflict resolution
    if (fileModifiedTime != null) {
      final localTime = DateTime.tryParse(localUpdatedAt) ?? DateTime(1970);
      
      // Priority 1: If the file on Drive was modified after the local record, accept remote
      if (fileModifiedTime.isAfter(localTime)) {
        return remote;
      }
      
      // Priority 2: If file modified time equals local time, compare versions
      if (fileModifiedTime.isAtSameMomentAs(localTime) || 
          (fileModifiedTime.isBefore(localTime) && fileModifiedTime.difference(localTime).abs().inSeconds < 2)) {
        // Timestamps are very close (within 2 seconds), use version comparison
        if (remoteVersion > localVersion) {
          return remote;
        } else if (localVersion > remoteVersion) {
          return null; // Keep local - local version is higher
        } else {
          // Versions are equal and timestamps are close - compare remote updatedAt
          final remoteTime = DateTime.tryParse(remoteUpdatedAt) ?? DateTime(1970);
          if (remoteTime.isAfter(localTime)) {
            return remote;
          } else {
            return null; // Keep local - local is newer or equal
          }
        }
      }
      
      // Priority 3: File modified time is before local time
      // Check version to determine which is newer
      if (remoteVersion > localVersion) {
        return remote; // Remote version is higher despite older file time
      } else if (localVersion > remoteVersion) {
        return null; // Keep local - local version is higher
      } else {
        // Versions are equal, file time is older - keep local
        return null;
      }
    }

    // Fallback logic when fileModifiedTime is not available
    // Priority 1: Compare versions
    if (remoteVersion > localVersion) {
      return remote;
    } else if (localVersion > remoteVersion) {
      return null; // Keep local - local version is higher
    } else {
      // Versions are equal - compare timestamps
      final localTime = DateTime.tryParse(localUpdatedAt) ?? DateTime(1970);
      final remoteTime = DateTime.tryParse(remoteUpdatedAt) ?? DateTime(1970);
      
      if (remoteTime.isAfter(localTime)) {
        return remote; // Remote timestamp is newer
      } else if (localTime.isAfter(remoteTime)) {
        return null; // Keep local - local timestamp is newer
      } else {
        // Timestamps are equal - no update needed (data should be identical)
        return null;
      }
    }
  }

  /// Check if local and remote data are identical (excluding sync metadata)
  bool _isDataIdentical(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    String tableName,
  ) {
    // Fields to exclude from comparison (sync metadata)
    final excludeFields = {'version', 'sync_status', 'updatedAt', 'createdAt'};
    
    // Create copies without sync metadata
    final localData = Map<String, dynamic>.from(local);
    final remoteData = Map<String, dynamic>.from(remote);
    
    excludeFields.forEach((field) {
      localData.remove(field);
      remoteData.remove(field);
    });
    
    // Compare JSON strings for deep equality
    try {
      final localJson = jsonEncode(localData);
      final remoteJson = jsonEncode(remoteData);
      return localJson == remoteJson;
    } catch (e) {
      // If JSON encoding fails, do field-by-field comparison
      if (localData.length != remoteData.length) {
        return false;
      }
      
      for (final key in localData.keys) {
        if (localData[key] != remoteData[key]) {
          return false;
        }
      }
      return true;
    }
  }

  Future<void> _insertUserFromDrive(Map<String, dynamic> data) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('users', {
      'id': data['id'],
      'email': data['email'],
      'password': data['password'],
      'role': data['role'],
      'name': data['name'],
      'mobileNumber': data['mobileNumber'] ?? '',
      'createdBy': data['createdBy'],
      'createdAt': data['createdAt'],
      'lastLoginTime': data['lastLoginTime'],
      'version': data['version'] ?? 1,
      'sync_status': 'SYNCED',
      'updatedAt': data['updatedAt'] ?? now,
    });
  }

  Future<void> _insertCompanyFromDrive(Map<String, dynamic> data) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('companies', {
      'id': data['id'],
      'name': data['name'],
      'address': data['address'],
      'mobile': data['mobile'],
      'email': data['email'],
      'createdAt': data['createdAt'],
      'version': data['version'] ?? 1,
      'sync_status': 'SYNCED',
      'updatedAt': data['updatedAt'] ?? now,
    });
  }

  Future<void> _insertQuotationFromDrive(Map<String, dynamic> data) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    
    try {
      await db.insert('quotations_history', {
        'id': data['id'],
        'quotationNumber': data['quotationNumber'],
        'quotationDate': data['quotationDate'],
        'customerName': data['customerName'],
        'customerAddress': data['customerAddress'],
        'customerContact': data['customerContact'],
        'customerEmail': data['customerEmail'],
        'items': data['items'],
        'totalAmount': data['totalAmount'],
        'totalGstAmount': data['totalGstAmount'],
        'grandTotal': data['grandTotal'],
        'action': data['action'],
        'createdBy': data['createdBy'],
        'createdAt': data['createdAt'],
        'version': data['version'] ?? 1,
        'sync_status': 'SYNCED',
        'updatedAt': data['updatedAt'] ?? now,
      });
    } catch (e) {
      // If insert fails due to UNIQUE constraint (id already exists), try to update instead
      if (e.toString().contains('UNIQUE constraint') || e.toString().contains('1555')) {
        debugPrint('Quotation with id ${data['id']} already exists, updating instead...');
        await db.update(
          'quotations_history',
          {
            'quotationNumber': data['quotationNumber'],
            'quotationDate': data['quotationDate'],
            'customerName': data['customerName'],
            'customerAddress': data['customerAddress'],
            'customerContact': data['customerContact'],
            'customerEmail': data['customerEmail'],
            'items': data['items'],
            'totalAmount': data['totalAmount'],
            'totalGstAmount': data['totalGstAmount'],
            'grandTotal': data['grandTotal'],
            'action': data['action'],
            'createdBy': data['createdBy'],
            'createdAt': data['createdAt'],
            'version': data['version'] ?? 1,
            'sync_status': 'SYNCED',
            'updatedAt': data['updatedAt'] ?? now,
          },
          where: 'id = ?',
          whereArgs: [data['id']],
        );
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    }
  }

  Future<void> _insertMyCompanyFromDrive(Map<String, dynamic> data) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('my_company', {
      'id': 1,
      'name': data['name'],
      'address': data['address'],
      'mobile': data['mobile'],
      'email': data['email'],
      'gstin': data['gstin'] ?? '',
      'updatedAt': data['updatedAt'] ?? now,
      'version': data['version'] ?? 1,
      'sync_status': 'SYNCED',
    });
  }

  String _userToJson(Map<String, dynamic> user) {
    return jsonEncode({
      'id': user['id'],
      'email': user['email'],
      'password': user['password'],
      'role': user['role'],
      'name': user['name'],
      'mobileNumber': user['mobileNumber'],
      'createdBy': user['createdBy'],
      'createdAt': user['createdAt'],
      'lastLoginTime': user['lastLoginTime'],
      'version': user['version'] ?? 1,
      'updatedAt': user['updatedAt'] ?? user['createdAt'],
    });
  }

  String _companyToJson(Map<String, dynamic> company) {
    return jsonEncode({
      'id': company['id'],
      'name': company['name'],
      'address': company['address'],
      'mobile': company['mobile'],
      'email': company['email'],
      'createdAt': company['createdAt'],
      'version': company['version'] ?? 1,
      'updatedAt': company['updatedAt'] ?? company['createdAt'],
    });
  }

  String _quotationToJson(Map<String, dynamic> quotation) {
    return jsonEncode({
      'id': quotation['id'],
      'quotationNumber': quotation['quotationNumber'],
      'quotationDate': quotation['quotationDate'],
      'customerName': quotation['customerName'],
      'customerAddress': quotation['customerAddress'],
      'customerContact': quotation['customerContact'],
      'customerEmail': quotation['customerEmail'],
      'items': quotation['items'],
      'totalAmount': quotation['totalAmount'],
      'totalGstAmount': quotation['totalGstAmount'],
      'grandTotal': quotation['grandTotal'],
      'action': quotation['action'],
      'createdBy': quotation['createdBy'],
      'createdAt': quotation['createdAt'],
      'version': quotation['version'] ?? 1,
      'updatedAt': quotation['updatedAt'] ?? quotation['createdAt'],
    });
  }

  String _myCompanyToJson(Map<String, dynamic> myCompany) {
    return jsonEncode({
      'id': myCompany['id'],
      'name': myCompany['name'],
      'address': myCompany['address'],
      'mobile': myCompany['mobile'],
      'email': myCompany['email'],
      'gstin': myCompany['gstin'],
      'updatedAt': myCompany['updatedAt'],
      'version': myCompany['version'] ?? 1,
    });
  }

  Future<DateTime?> _getLastSyncTime() async {
    try {
      final fileId = await _driveService.findFileByName('last_sync.json', 'sync');
      if (fileId == null) {
        return null;
      }

      final content = await _driveService.downloadFile(fileId);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final timeStr = data['lastSync'] as String?;
      return timeStr != null ? DateTime.parse(timeStr) : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateLastSyncTime(DateTime time) async {
    try {
      // Ensure folder structure is initialized
      await _driveService.getFolderId('sync');
      
      final json = jsonEncode({
        'lastSync': time.toIso8601String(),
      });

      final existingFileId = await _driveService.findFileByName('last_sync.json', 'sync');
      await _driveService.uploadFile(
        fileName: 'last_sync.json',
        content: json,
        folderName: 'sync',
        fileId: existingFileId,
      );
    } catch (e) {
      debugPrint('Error updating last sync time: $e');
    }
  }

  Future<void> _logSync(SyncResult result, DateTime syncTime) async {
    try {
      // Ensure folder structure is initialized
      await _driveService.getFolderId('sync');
      
      final fileId = await _driveService.findFileByName('sync_log.json', 'sync');
      final existingContent = fileId != null
          ? await _driveService.downloadFile(fileId)
          : '[]';
      
      final logs = (jsonDecode(existingContent) as List).cast<Map<String, dynamic>>();
      logs.add({
        'timestamp': syncTime.toIso8601String(),
        'success': result.success,
        'usersSynced': result.usersSynced,
        'companiesSynced': result.companiesSynced,
        'quotationsSynced': result.quotationsSynced,
        'myCompanySynced': result.myCompanySynced,
        'usersDownloaded': result.usersDownloaded,
        'companiesDownloaded': result.companiesDownloaded,
        'quotationsDownloaded': result.quotationsDownloaded,
        'usersMerged': result.usersMerged,
        'companiesMerged': result.companiesMerged,
        'quotationsMerged': result.quotationsMerged,
        'errors': result.errors,
      });

      final json = jsonEncode(logs);
      await _driveService.uploadFile(
        fileName: 'sync_log.json',
        content: json,
        folderName: 'sync',
        fileId: fileId,
      );
    } catch (e) {
      debugPrint('Error logging sync: $e');
    }
  }

  Future<void> restoreFromGoogleDrive() async {
    try {
      if (!await GoogleAuthService.instance.loadStoredTokens()) {
        throw Exception('Not authenticated with Google');
      }

      final db = await _db.database;
      
      await db.transaction((txn) async {
        await txn.delete('users');
        await txn.delete('companies');
        await txn.delete('quotations_history');
        await txn.delete('my_company');
      });

      final result = SyncResult();
      await _downloadUsers(null, true, result);
      await _downloadCompanies(null, true, result);
      await _downloadQuotations(null, true, result);
      await _downloadMyCompany(null, true, result);

      await _createDefaultAdminIfNeeded(db);
    } catch (e) {
      throw Exception('Restore failed: $e');
    }
  }

  Future<void> _createDefaultAdminIfNeeded(Database db) async {
    final adminExists = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: ['admin@gmail.com'],
    );

    if (adminExists.isEmpty) {
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
        'version': 1,
        'sync_status': 'SYNCED',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class SyncResult {
  bool success = false;
  int usersSynced = 0;
  int companiesSynced = 0;
  int quotationsSynced = 0;
  int myCompanySynced = 0;
  int usersDownloaded = 0;
  int companiesDownloaded = 0;
  int quotationsDownloaded = 0;
  bool myCompanyDownloaded = false;
  int usersMerged = 0;
  int companiesMerged = 0;
  int quotationsMerged = 0;
  bool myCompanyMerged = false;
  final List<String> errors = [];
}

