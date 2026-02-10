import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import 'desktop_oauth_service.dart';

class GoogleAuthService extends ChangeNotifier {
  static final GoogleAuthService instance = GoogleAuthService._init();
  GoogleAuthService._init();

  final _storage = SecureStorageServiceImpl.instance;
  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _expiryKey = 'google_token_expiry';
  static const _scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  // TODO: Replace with your OAuth 2.0 Client ID from Google Cloud Console
  // Get it from: https://console.cloud.google.com/apis/credentials
  // Application type: Desktop app
  // 
  // For now, leaving it empty - google_sign_in will try to use default configuration
  // If sign-in fails, you MUST add your Client ID here
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // Uncomment and add your Client ID when you get it from Google Cloud Console:
    // clientId: 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  DateTime? _tokenExpiry;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DesktopOAuthService.instance.isSignedIn;
    }
    return _currentUser != null;
  }
  String? get accessToken => _accessToken;

  Future<bool> signIn() async {
    try {
      // Use desktop OAuth for Windows/Linux/macOS, google_sign_in for mobile
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final success = await DesktopOAuthService.instance.signIn();
        if (success) {
          _accessToken = DesktopOAuthService.instance.accessToken;
          final verified = await verifyDriveAccess();
          if (!verified) {
            throw Exception('Failed to verify Google Drive access. Please check permissions.');
          }
          notifyListeners(); // Notify listeners of successful sign-in
          return true;
        }
        return false;
      } else {
        // Mobile platforms use google_sign_in
        final account = await _googleSignIn.signIn();
        if (account == null) {
          throw Exception('Sign-in was cancelled by user');
        }

        _currentUser = account;
        final auth = await account.authentication;

        if (auth.accessToken == null) {
          throw Exception('Failed to obtain access token. Please check OAuth configuration.');
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

        final verified = await verifyDriveAccess();
        if (!verified) {
          throw Exception('Failed to verify Google Drive access. Please check permissions.');
        }
        notifyListeners(); // Notify listeners of successful sign-in
        return true;
      }
    } catch (e) {
      rethrow;
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

      final verified = await verifyDriveAccess();
      if (verified) {
        notifyListeners(); // Notify listeners when silently signed in
      }
      return verified;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await DesktopOAuthService.instance.signOut();
      } else {
        await _googleSignIn.signOut();
        await _storage.delete(key: _accessTokenKey);
        await _storage.delete(key: _refreshTokenKey);
        await _storage.delete(key: _expiryKey);
      }
      _currentUser = null;
      _accessToken = null;
      _tokenExpiry = null;
      notifyListeners(); // Notify listeners of sign-out
    } catch (e) {
      // Ignore errors during sign out
    }
  }

  Future<bool> loadStoredTokens() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final result = await DesktopOAuthService.instance.loadStoredTokens();
        if (result) {
          _accessToken = DesktopOAuthService.instance.accessToken;
          // Sync token expiry from DesktopOAuthService
          // We need to get it from the stored tokens since DesktopOAuthService doesn't expose it directly
          final storedExpiry = await _storage.read(key: _expiryKey);
          if (storedExpiry != null) {
            _tokenExpiry = DateTime.parse(storedExpiry);
          }
          notifyListeners(); // Notify listeners when tokens are loaded
        }
        return result;
      } else {
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
          final verified = await verifyDriveAccess();
          if (verified) {
            notifyListeners(); // Notify listeners when tokens are loaded
          }
          return verified;
        }

        return false;
      }
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

      notifyListeners(); // Notify listeners when token is refreshed
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getValidAccessToken() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Always use DesktopOAuthService's getValidAccessToken which handles refresh automatically
      final token = await DesktopOAuthService.instance.getValidAccessToken();
      if (token != null) {
        // Sync the token and expiry from DesktopOAuthService to this service
        if (_accessToken != token) {
          _accessToken = token;
          // Update expiry from storage
          final storedExpiry = await _storage.read(key: _expiryKey);
          if (storedExpiry != null) {
            _tokenExpiry = DateTime.parse(storedExpiry);
          }
          notifyListeners(); // Notify if token was refreshed
        }
      }
      return token;
    }
    
    if (_accessToken == null || _tokenExpiry == null) {
      final loaded = await loadStoredTokens();
      if (!loaded) {
        return null;
      }
    }

    // Check if token is expired or about to expire (within 10 minutes)
    // Google tokens typically expire after 1 hour (3600 seconds)
    // Refreshing 10 minutes early (600 seconds) gives us a safe buffer
    if (_tokenExpiry != null) {
      final now = DateTime.now();
      final timeUntilExpiry = _tokenExpiry!.difference(now);
      
      // Refresh if expired or expiring within 10 minutes (600 seconds)
      if (timeUntilExpiry.isNegative || timeUntilExpiry.inSeconds < 600) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          return null;
        }
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

