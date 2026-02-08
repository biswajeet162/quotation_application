import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'authenticated_http_client.dart';

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._init();
  GoogleDriveService._init();

  static const String _rootFolderName = 'QuotationAppData';
  static const String _metaFolderName = 'meta';
  static const String _usersFolderName = 'users';
  static const String _companiesFolderName = 'companies';
  static const String _quotationsFolderName = 'quotations';
  static const String _myCompanyFolderName = 'my_company';
  static const String _syncFolderName = 'sync';
  static const String _backupsFolderName = 'backups';

  drive.DriveApi? _driveApi;
  String? _rootFolderId;
  final Map<String, String> _folderIds = {};

  Future<void> _ensureInitialized() async {
    if (_driveApi != null && _rootFolderId != null) {
      return;
    }

    if (!await GoogleAuthService.instance.loadStoredTokens()) {
      throw Exception('Not authenticated with Google');
    }

    final baseClient = http.Client();
    final authClient = AuthenticatedHttpClient(baseClient);

    _driveApi = drive.DriveApi(authClient);
    _rootFolderId = await _findOrCreateRootFolder();
    await _initializeFolderStructure();
  }

  Future<String> _findOrCreateRootFolder() async {
    if (_rootFolderId != null) {
      return _rootFolderId!;
    }

    final query = "name='$_rootFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      _rootFolderId = response.files!.first.id!;
      return _rootFolderId!;
    }

    final folder = drive.File();
    folder.name = _rootFolderName;
    folder.mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folder);
    _rootFolderId = created.id!;
    return _rootFolderId!;
  }

  Future<void> _initializeFolderStructure() async {
    if (_rootFolderId == null) return;

    final folders = [
      _metaFolderName,
      _usersFolderName,
      _companiesFolderName,
      _quotationsFolderName,
      _myCompanyFolderName,
      _syncFolderName,
      _backupsFolderName,
    ];

    for (final folderName in folders) {
      final folderId = await _findOrCreateFolder(folderName, _rootFolderId!);
      _folderIds[folderName] = folderId;
    }

    await _initializeMetaFiles();
  }

  Future<void> _initializeMetaFiles() async {
    final metaFolderId = _folderIds[_metaFolderName];
    if (metaFolderId == null) return;

    try {
      final appJsonId = await findFileByName('app.json', 'meta');
      if (appJsonId == null) {
        final appJson = jsonEncode({
          'appName': 'Quotation Application',
          'version': '1.0.0',
          'createdAt': DateTime.now().toIso8601String(),
        });
        await uploadFile(
          fileName: 'app.json',
          content: appJson,
          folderName: 'meta',
        );
      }

      final schemaVersionId = await findFileByName('schema_version.json', 'meta');
      if (schemaVersionId == null) {
        final schemaVersion = jsonEncode({
          'version': 11,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        await uploadFile(
          fileName: 'schema_version.json',
          content: schemaVersion,
          folderName: 'meta',
        );
      }
    } catch (e) {
      // Ignore errors during meta file initialization
    }
  }

  Future<String> _findOrCreateFolder(String folderName, String parentId) async {
    final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and '$parentId' in parents and trashed=false";
    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id!;
    }

    final folder = drive.File();
    folder.name = folderName;
    folder.mimeType = 'application/vnd.google-apps.folder';
    folder.parents = [parentId];

    final created = await _driveApi!.files.create(folder);
    return created.id!;
  }

  Future<String?> findFolderByName(String folderName, {String? parentId}) async {
    await _ensureInitialized();
    
    final parent = parentId ?? _rootFolderId;
    final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false${parent != null ? " and '$parent' in parents" : ''}";
    
    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id;
    }

    return null;
  }

  Future<String> uploadFile({
    required String fileName,
    required String content,
    required String folderName,
    String? fileId,
  }) async {
    await _ensureInitialized();

    final folderId = _folderIds[folderName];
    if (folderId == null) {
      throw Exception('Folder $folderName not found');
    }

    final fileMetadata = drive.File();
    fileMetadata.name = fileName;

    final media = drive.Media(
      Stream.fromIterable([utf8.encode(content)]),
      utf8.encode(content).length,
      contentType: 'application/json',
    );

    if (fileId != null) {
      // Don't set parents when updating - it's not writable in update requests
      final updated = await _driveApi!.files.update(
        fileMetadata,
        fileId,
        uploadMedia: media,
      );
      return updated.id!;
    } else {
      // Only set parents when creating a new file
      fileMetadata.parents = [folderId];
      final created = await _driveApi!.files.create(
        fileMetadata,
        uploadMedia: media,
      );
      return created.id!;
    }
  }

  Future<String?> findFileByName(String fileName, String folderName) async {
    await _ensureInitialized();

    final folderId = _folderIds[folderName];
    if (folderId == null) {
      return null;
    }

    final query = "name='$fileName' and '$folderId' in parents and trashed=false";
    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id;
    }

    return null;
  }

  Future<String> downloadFile(String fileId) async {
    await _ensureInitialized();

    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
  }

  Future<List<drive.File>> listFilesInFolder(
    String folderName, {
    DateTime? modifiedAfter,
  }) async {
    await _ensureInitialized();

    final folderId = _folderIds[folderName];
    if (folderId == null) {
      return [];
    }

    String query = "'$folderId' in parents and trashed=false";
    if (modifiedAfter != null) {
      // Subtract 2 hours buffer to account for clock differences and ensure we don't miss files
      // that were uploaded just before the last sync time
      final bufferTime = modifiedAfter.subtract(const Duration(hours: 2));
      final timeStr = bufferTime.toUtc().toIso8601String();
      query += " and modifiedTime > '$timeStr'";
    }

    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
    );

    return response.files ?? [];
  }

  Future<List<drive.File>> listFilesInSubfolder(
    String parentFolderName,
    String subfolderName, {
    DateTime? modifiedAfter,
  }) async {
    await _ensureInitialized();

    final parentFolderId = _folderIds[parentFolderName];
    if (parentFolderId == null) {
      return [];
    }

    final subfolderId = await _findOrCreateFolder(subfolderName, parentFolderId);

    String query = "'$subfolderId' in parents and trashed=false";
    if (modifiedAfter != null) {
      // Subtract 2 hours buffer to account for clock differences and ensure we don't miss files
      // that were uploaded just before the last sync time
      final bufferTime = modifiedAfter.subtract(const Duration(hours: 2));
      final timeStr = bufferTime.toUtc().toIso8601String();
      query += " and modifiedTime > '$timeStr'";
    }

    final response = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
    );

    return response.files ?? [];
  }

  Future<void> deleteFile(String fileId) async {
    await _ensureInitialized();
    await _driveApi!.files.delete(fileId);
  }

  Future<String> getRootFolderId() async {
    await _ensureInitialized();
    return _rootFolderId!;
  }

  Future<String> getFolderId(String folderName) async {
    await _ensureInitialized();
    
    // If folder ID is already cached, return it
    if (_folderIds.containsKey(folderName) && _folderIds[folderName] != null) {
      return _folderIds[folderName]!;
    }
    
    // Try to find the folder
    final folderId = await _findOrCreateFolder(folderName, _rootFolderId!);
    _folderIds[folderName] = folderId;
    return folderId;
  }

  Future<String> findOrCreateFolder(String folderName, String parentId) async {
    await _ensureInitialized();
    return await _findOrCreateFolder(folderName, parentId);
  }
}

