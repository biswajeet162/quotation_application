import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

abstract class SecureStorageService {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

class SecureStorageServiceImpl implements SecureStorageService {
  static SecureStorageServiceImpl? _instance;
  static SecureStorageServiceImpl get instance {
    _instance ??= SecureStorageServiceImpl._init();
    return _instance!;
  }

  SecureStorageServiceImpl._init();

  final SecureStorageService _impl = EncryptedFileStorage();

  @override
  Future<void> write({required String key, required String? value}) {
    return _impl.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _impl.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _impl.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _impl.deleteAll();
  }
}

class EncryptedFileStorage implements SecureStorageService {
  static const String _keyPrefix = 'secure_';
  String? _storageDir;

  Future<String> _getStorageDir() async {
    if (_storageDir != null) return _storageDir!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appDir = await getApplicationSupportDirectory();
      final secureDir = path.join(appDir.path, 'secure_storage');
      final dir = Directory(secureDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _storageDir = secureDir;
      return secureDir;
    } else {
      final appDir = await getApplicationSupportDirectory();
      _storageDir = appDir.path;
      return appDir.path;
    }
  }

  String _getKey(String key) {
    return '$_keyPrefix$key';
  }

  String _deriveKey(String key) {
    final bytes = utf8.encode('quotation_app_secret_key_$key');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  String _encrypt(String value, String key) {
    final keyBytes = utf8.encode(_deriveKey(key));
    final valueBytes = utf8.encode(value);
    
    final encrypted = <int>[];
    for (int i = 0; i < valueBytes.length; i++) {
      encrypted.add(valueBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64Encode(encrypted);
  }

  String _decrypt(String encrypted, String key) {
    final keyBytes = utf8.encode(_deriveKey(key));
    final encryptedBytes = base64Decode(encrypted);
    
    final decrypted = <int>[];
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    final storageDir = await _getStorageDir();
    final fileKey = _getKey(key);
    final file = File(path.join(storageDir, fileKey));

    if (value == null) {
      if (await file.exists()) {
        await file.delete();
      }
    } else {
      final encrypted = _encrypt(value, key);
      await file.writeAsString(encrypted);
    }
  }

  @override
  Future<String?> read({required String key}) async {
    try {
      final storageDir = await _getStorageDir();
      final fileKey = _getKey(key);
      final file = File(path.join(storageDir, fileKey));

      if (!await file.exists()) {
        return null;
      }

      final encrypted = await file.readAsString();
      return _decrypt(encrypted, key);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    final storageDir = await _getStorageDir();
    final fileKey = _getKey(key);
    final file = File(path.join(storageDir, fileKey));

    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final storageDir = await _getStorageDir();
      final dir = Directory(storageDir);
      
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.contains(_keyPrefix)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

