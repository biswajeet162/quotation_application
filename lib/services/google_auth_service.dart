import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._init();
  GoogleAuthService._init();

  final _storage = SecureStorageServiceImpl.instance;
  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _expiryKey = 'google_token_expiry';
  static const _scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  DateTime? _tokenExpiry;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get accessToken => _accessToken;

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      _currentUser = account;
      final auth = await account.authentication;

      if (auth.accessToken == null) {
        return false;
      }

      _accessToken = auth.accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

      await _storage.write(key: _accessTokenKey, value: _accessToken);
      if (auth.idToken != null) {
        await _storage.write(key: _refreshTokenKey, value: auth.idToken);
      }
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );

      return await verifyDriveAccess();
    } catch (e) {
      return false;
    }
  }

  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        return false;
      }

      _currentUser = account;
      final auth = await account.authentication;

      if (auth.accessToken == null) {
        return false;
      }

      _accessToken = auth.accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

      await _storage.write(key: _accessTokenKey, value: _accessToken);
      if (auth.idToken != null) {
        await _storage.write(key: _refreshTokenKey, value: auth.idToken);
      }
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );

      return await verifyDriveAccess();
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _expiryKey);
      _currentUser = null;
      _accessToken = null;
      _tokenExpiry = null;
    } catch (e) {
      // Ignore errors during sign out
    }
  }

  Future<bool> loadStoredTokens() async {
    try {
      final storedToken = await _storage.read(key: _accessTokenKey);
      final storedExpiry = await _storage.read(key: _expiryKey);

      if (storedToken == null || storedExpiry == null) {
        return false;
      }

      final expiry = DateTime.parse(storedExpiry);
      if (expiry.isBefore(DateTime.now())) {
        return await refreshToken();
      }

      _accessToken = storedToken;
      _tokenExpiry = expiry;

      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        return await verifyDriveAccess();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refreshToken() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        return false;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        return false;
      }

      _currentUser = account;
      _accessToken = auth.accessToken;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

      await _storage.write(key: _accessTokenKey, value: _accessToken);
      if (auth.idToken != null) {
        await _storage.write(key: _refreshTokenKey, value: auth.idToken);
      }
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getValidAccessToken() async {
    if (_accessToken == null || _tokenExpiry == null) {
      final loaded = await loadStoredTokens();
      if (!loaded) {
        return null;
      }
    }

    if (_tokenExpiry != null && _tokenExpiry!.isBefore(DateTime.now())) {
      final refreshed = await refreshToken();
      if (!refreshed) {
        return null;
      }
    }

    return _accessToken;
  }

  Future<bool> verifyDriveAccess() async {
    try {
      final token = await getValidAccessToken();
      if (token == null) {
        return false;
      }

      final client = http.Client();
      final authHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await client.get(
        Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
        headers: authHeaders,
      );

      client.close();

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

