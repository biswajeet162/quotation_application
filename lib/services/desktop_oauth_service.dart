import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/oauth_config.dart';
import 'secure_storage_service.dart';

class DesktopOAuthService {
  static final DesktopOAuthService instance = DesktopOAuthService._init();
  DesktopOAuthService._init();

  final _storage = SecureStorageServiceImpl.instance;
  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _expiryKey = 'google_token_expiry';
  static const _codeVerifierKey = 'oauth_code_verifier';

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _refreshToken;
  
  // Cache to prevent repeated checks
  bool _hasCheckedTokens = false;
  bool _tokensExist = false;
  DateTime? _lastTokenCheck;
  static const _tokenCheckCacheDuration = Duration(seconds: 30);
  
  // Periodic token refresh timer
  Timer? _tokenRefreshTimer;

  String? get accessToken => _accessToken;
  bool get isSignedIn => _accessToken != null;

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(128, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _startLocalServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, OAuthConfig.callbackPort);
    
    server.listen((request) async {
      if (request.uri.path == '/callback') {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];
        
        if (error != null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
                <body>
                  <h1>Authentication Failed</h1>
                  <p>Error: $error</p>
                  <p>You can close this window.</p>
                </body>
              </html>
            ''');
          await request.response.close();
          await server.close(force: true);
          return;
        }
        
        if (code != null) {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
                <body>
                  <h1>Authentication Successful!</h1>
                  <p>You can close this window and return to the application.</p>
                  <script>window.close();</script>
                </body>
              </html>
            ''');
          await request.response.close();
          
          // Store code for token exchange
          await _storage.write(key: 'oauth_auth_code', value: code);
          await server.close(force: true);
        } else {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
                <body>
                  <h1>Authentication Failed</h1>
                  <p>No authorization code received.</p>
                  <p>You can close this window.</p>
                </body>
              </html>
            ''');
          await request.response.close();
          await server.close(force: true);
        }
      }
    });
  }

  Future<bool> signIn() async {
    try {
      if (!OAuthConfig.isConfigured) {
        throw Exception(
          'Please configure your OAuth Client ID in lib/config/oauth_config.dart\n'
          'Get it from: https://console.cloud.google.com/apis/credentials\n'
          'Application type: Desktop app\n'
          'Copy oauth_config.example.dart to oauth_config.dart and add your Client ID'
        );
      }

      // Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      await _storage.write(key: _codeVerifierKey, value: codeVerifier);

      // Build authorization URL
      final authUrl = Uri.parse(OAuthConfig.authEndpoint).replace(queryParameters: {
        'client_id': OAuthConfig.clientId,
        'redirect_uri': OAuthConfig.redirectUri,
        'response_type': 'code',
        'scope': OAuthConfig.scopes.join(' '),
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      // Start local server to receive callback
      await _startLocalServer();

      // Open browser
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Failed to open browser. Please check your default browser settings.');
      }

      // Wait for authorization code (polling)
      String? authCode;
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 1));
        authCode = await _storage.read(key: 'oauth_auth_code');
        if (authCode != null) {
          await _storage.delete(key: 'oauth_auth_code');
          break;
        }
      }

      if (authCode == null) {
        throw Exception('Authentication timeout. Please try again.');
      }

      // Retrieve code verifier from storage to ensure we use the exact same one
      final storedCodeVerifier = await _storage.read(key: _codeVerifierKey);
      if (storedCodeVerifier == null || storedCodeVerifier.isEmpty) {
        throw Exception('Code verifier not found. Please try signing in again.');
      }

      // Exchange authorization code for tokens
      // Always include both client_id and client_secret
      final body = <String, String>{
        'client_id': OAuthConfig.clientId,
        'client_secret': OAuthConfig.clientSecret,
        'code': authCode,
        'code_verifier': storedCodeVerifier,
        'redirect_uri': OAuthConfig.redirectUri,
        'grant_type': 'authorization_code',
      };

        final tokenResponse = await http.post(
        Uri.parse(OAuthConfig.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
        );

      if (tokenResponse.statusCode != 200) {
        final error = jsonDecode(tokenResponse.body);
        throw Exception('Token exchange failed: ${error['error_description'] ?? error['error']}');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      _accessToken = tokenData['access_token'] as String;
      _refreshToken = tokenData['refresh_token'] as String?;
      
      final expiresIn = tokenData['expires_in'] as int;
      // FOR TESTING: Override expiry to 2 minutes instead of actual expiry time
      const testExpirySeconds = 120; // 2 minutes
      _tokenExpiry = DateTime.now().add(Duration(seconds: testExpirySeconds));
      debugPrint('🧪 [TEST MODE] Token expiry overridden to ${testExpirySeconds}s (2 minutes) for testing (actual: ${expiresIn}s)');

      // Store tokens
      await _storage.write(key: _accessTokenKey, value: _accessToken);
      if (_refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: _refreshToken);
      }
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );

      // Clean up code verifier after successful token exchange
      await _storage.delete(key: _codeVerifierKey);

      // Clear cache after successful sign-in
      _hasCheckedTokens = true;
      _tokensExist = true;
      _lastTokenCheck = DateTime.now();

      // Start periodic token refresh to prevent automatic logout
      _startPeriodicTokenRefresh();

      return true;
    } catch (e) {
      // Clean up code verifier on error as well
      await _storage.delete(key: _codeVerifierKey);
      rethrow;
    }
  }

  Future<bool> loadStoredTokens({bool forceRefresh = false}) async {
    try {
      // Use cache to prevent repeated checks within short time period
      final now = DateTime.now();
      if (!forceRefresh && 
          _hasCheckedTokens && 
          _lastTokenCheck != null &&
          now.difference(_lastTokenCheck!) < _tokenCheckCacheDuration) {
        // Return cached result if checked recently
        return _tokensExist;
      }

      final storedToken = await _storage.read(key: _accessTokenKey);
      final storedExpiry = await _storage.read(key: _expiryKey);
      _refreshToken = await _storage.read(key: _refreshTokenKey);

      // Update cache
      _hasCheckedTokens = true;
      _lastTokenCheck = now;

      // If no tokens stored at all, user needs to sign in
      if (storedToken == null || storedExpiry == null) {
        _tokensExist = false;
        // Only log once per cache period to prevent flooding
        if (!_hasCheckedTokens || forceRefresh) {
          debugPrint('No stored tokens found - user needs to sign in');
        }
        return false;
      }
      
      _tokensExist = true;

      final expiry = DateTime.parse(storedExpiry);
      final timeSinceExpiry = now.difference(expiry);
      
      // If token is expired (even by hours/days), refresh it automatically
      if (expiry.isBefore(now)) {
        debugPrint('🚨 [LOAD TOKENS] Access token expired ${timeSinceExpiry.inHours} hours ago, refreshing...');
        debugPrint('🚨 [LOAD TOKENS] Token expired at: ${expiry.toIso8601String()}');
        debugPrint('🚨 [LOAD TOKENS] Current time: ${now.toIso8601String()}');
        final refreshed = await refreshToken();
        if (refreshed) {
          debugPrint('✅ [LOAD TOKENS] Token refreshed successfully after ${timeSinceExpiry.inHours} hours');
          return true;
        } else {
          debugPrint('❌ [LOAD TOKENS] Failed to refresh token - refresh token may be expired or invalid');
          return false;
        }
      }

      // Token is still valid - only log on first load to avoid spam
      final wasAlreadyLoaded = _accessToken != null && _tokenExpiry != null;
      _accessToken = storedToken;
      _tokenExpiry = expiry;
      
      final minutesUntilExpiry = expiry.difference(now).inMinutes;
      final secondsUntilExpiry = expiry.difference(now).inSeconds % 60;
      
      // Only log when first loading tokens, not on every check
      if (!wasAlreadyLoaded && (forceRefresh || !_hasCheckedTokens)) {
        debugPrint('✅ [LOAD TOKENS] Stored token loaded successfully');
        debugPrint('⏰ [LOAD TOKENS] Token expires in ${minutesUntilExpiry}m ${secondsUntilExpiry}s');
        debugPrint('⏰ [LOAD TOKENS] Token expires at: ${expiry.toIso8601String()}');
        debugPrint('🔄 [LOAD TOKENS] Starting periodic token refresh timer...');
        // Start periodic token refresh if tokens were just loaded
        _startPeriodicTokenRefresh();
      }
      _tokensExist = true;
      return true;
    } catch (e) {
      debugPrint('Error loading stored tokens: $e');
      return false;
    }
  }

  Future<bool> refreshToken() async {
    debugPrint('🔄 [REFRESH TOKEN] Starting token refresh process...');
    try {
      if (_refreshToken == null) {
        debugPrint('📥 [REFRESH TOKEN] Loading refresh token from storage...');
        final stored = await _storage.read(key: _refreshTokenKey);
        if (stored == null) {
          debugPrint('❌ [REFRESH TOKEN] Refresh token not found - user needs to re-authenticate');
          return false;
        }
        _refreshToken = stored;
        debugPrint('✅ [REFRESH TOKEN] Refresh token loaded from storage');
      } else {
        debugPrint('✅ [REFRESH TOKEN] Refresh token already in memory');
      }

      debugPrint('📤 [REFRESH TOKEN] Sending refresh token request to Google...');
      debugPrint('📤 [REFRESH TOKEN] Endpoint: ${OAuthConfig.tokenEndpoint}');
      debugPrint('📤 [REFRESH TOKEN] Client ID: ${OAuthConfig.clientId.substring(0, 20)}...');
      
      final tokenResponse = await http.post(
        Uri.parse(OAuthConfig.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': OAuthConfig.clientId,
          'client_secret': OAuthConfig.clientSecret,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📥 [REFRESH TOKEN] Response received: Status ${tokenResponse.statusCode}');

      if (tokenResponse.statusCode != 200) {
        final errorBody = tokenResponse.body;
        debugPrint('❌ [REFRESH TOKEN] Token refresh failed: ${tokenResponse.statusCode} - $errorBody');
        
        // If refresh token is invalid/expired, clear stored tokens
        if (tokenResponse.statusCode == 400 || tokenResponse.statusCode == 401) {
          debugPrint('🚨 [REFRESH TOKEN] Refresh token expired or invalid - clearing stored tokens');
          await signOut();
        }
        return false;
      }

      debugPrint('✅ [REFRESH TOKEN] Parsing token response...');
      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      _accessToken = tokenData['access_token'] as String;
      debugPrint('✅ [REFRESH TOKEN] New access token received (length: ${_accessToken!.length})');
      
      // Update refresh token if provided (Google may issue a new one)
      if (tokenData.containsKey('refresh_token')) {
        _refreshToken = tokenData['refresh_token'] as String?;
        if (_refreshToken != null) {
          debugPrint('🔄 [REFRESH TOKEN] New refresh token received, saving to storage...');
          await _storage.write(key: _refreshTokenKey, value: _refreshToken);
          debugPrint('✅ [REFRESH TOKEN] New refresh token saved');
        }
      } else {
        debugPrint('ℹ️ [REFRESH TOKEN] No new refresh token provided, keeping existing one');
      }
      
      final expiresIn = tokenData['expires_in'] as int;
      // FOR TESTING: Override expiry to 2 minutes instead of actual expiry time
      const testExpirySeconds = 120; // 2 minutes
      _tokenExpiry = DateTime.now().add(Duration(seconds: testExpirySeconds));
      debugPrint('🧪 [TEST MODE] Token expiry overridden to ${testExpirySeconds}s (2 minutes) for testing (actual: ${expiresIn}s)');
      debugPrint('⏰ [REFRESH TOKEN] Token expiry set: ${_tokenExpiry!.toIso8601String()} (${testExpirySeconds}s from now)');

      debugPrint('💾 [REFRESH TOKEN] Saving tokens to storage...');
      await _storage.write(key: _accessTokenKey, value: _accessToken);
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );
      debugPrint('✅ [REFRESH TOKEN] Tokens saved to storage');

      debugPrint('✅ [REFRESH TOKEN] Token refreshed successfully, expires in ${expiresIn}s (${expiresIn ~/ 60} minutes)');
      
      // Restart periodic refresh timer after successful refresh
      debugPrint('🔄 [REFRESH TOKEN] Restarting periodic refresh timer...');
      _startPeriodicTokenRefresh();
      
      return true;
    } catch (e) {
      debugPrint('❌ [REFRESH TOKEN] Token refresh error: $e');
      debugPrint('❌ [REFRESH TOKEN] Error type: ${e.runtimeType}');
      // If it's a timeout or network error, don't clear tokens
      // Only clear if it's an authentication error
      if (e.toString().contains('400') || e.toString().contains('401')) {
        debugPrint('🚨 [REFRESH TOKEN] Authentication error during refresh - clearing tokens');
        await signOut();
      }
      return false;
    }
  }

  Future<String?> getValidAccessToken() async {
    debugPrint('🔍 [GET TOKEN] getValidAccessToken() called');
    
    if (_accessToken == null || _tokenExpiry == null) {
      debugPrint('📥 [GET TOKEN] No token in memory, loading from storage...');
      final loaded = await loadStoredTokens(forceRefresh: false);
      if (!loaded) {
        // Only log if we haven't checked recently to avoid flooding
        if (_lastTokenCheck == null || 
            DateTime.now().difference(_lastTokenCheck!) > _tokenCheckCacheDuration) {
          debugPrint('❌ [GET TOKEN] Failed to load stored tokens');
        }
        return null;
      }
      debugPrint('✅ [GET TOKEN] Tokens loaded from storage');
    } else {
      debugPrint('✅ [GET TOKEN] Token already in memory');
    }

    // Check if token is expired or about to expire (within 10 minutes)
    // Google tokens typically expire after 1 hour (3600 seconds)
    // Refreshing 10 minutes early (600 seconds) gives us a safe buffer
    if (_tokenExpiry != null) {
      final now = DateTime.now();
      final timeUntilExpiry = _tokenExpiry!.difference(now);
      final minutesLeft = timeUntilExpiry.inMinutes;
      final secondsLeft = timeUntilExpiry.inSeconds % 60;
      
      debugPrint('⏰ [GET TOKEN] Token status: ${minutesLeft}m ${secondsLeft}s until expiry');
      
      // Refresh if expired or expiring within 10 minutes (600 seconds)
      // This is approximately 1/6 of the token lifetime, providing a safe buffer
      if (timeUntilExpiry.isNegative || timeUntilExpiry.inSeconds < 600) {
        // Only log if token is actually expired or very close (within 1 minute)
        // This prevents log spam when checking on every HTTP request
        if (timeUntilExpiry.isNegative || timeUntilExpiry.inSeconds < 60) {
          debugPrint('🚨 [GET TOKEN] Token expired or expiring soon (${timeUntilExpiry.inMinutes} min remaining), refreshing...');
        }
        final refreshed = await refreshToken();
        if (!refreshed) {
          debugPrint('❌ [GET TOKEN] Token refresh failed - user needs to re-authenticate');
          return null;
        }
        debugPrint('✅ [GET TOKEN] Token refreshed, returning new token');
      } else {
        debugPrint('✅ [GET TOKEN] Token still valid, returning existing token');
      }
    }

    debugPrint('✅ [GET TOKEN] Returning access token (length: ${_accessToken?.length ?? 0})');
    return _accessToken;
  }

  Future<void> signOut() async {
    try {
      // Stop periodic token refresh
      _stopPeriodicTokenRefresh();
      
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _expiryKey);
      await _storage.delete(key: _codeVerifierKey);
      _accessToken = null;
      _tokenExpiry = null;
      _refreshToken = null;
      // Clear cache
      _hasCheckedTokens = false;
      _tokensExist = false;
      _lastTokenCheck = null;
    } catch (e) {
      // Ignore errors
    }
  }

  /// Start periodic token refresh to prevent automatic logout
  /// Refreshes tokens every 2 minutes (for testing)
  void _startPeriodicTokenRefresh() {
    _stopPeriodicTokenRefresh(); // Stop any existing timer
    
    debugPrint('🔄 [TOKEN REFRESH] Starting periodic token refresh timer (every 2 minutes)');
    
    // Refresh tokens every 2 minutes (for testing)
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      debugPrint('⏰ [TOKEN REFRESH] Periodic check triggered at ${DateTime.now().toIso8601String()}');
      
      if (_accessToken == null || _tokenExpiry == null) {
        debugPrint('⚠️ [TOKEN REFRESH] No tokens found - stopping timer');
        _stopPeriodicTokenRefresh();
        return;
      }
      
      final now = DateTime.now();
      final timeUntilExpiry = _tokenExpiry!.difference(now);
      final minutesLeft = timeUntilExpiry.inMinutes;
      final secondsLeft = timeUntilExpiry.inSeconds % 60;
      
      debugPrint('📊 [TOKEN REFRESH] Token status: ${minutesLeft}m ${secondsLeft}s until expiry');
      debugPrint('📊 [TOKEN REFRESH] Token expires at: ${_tokenExpiry!.toIso8601String()}');
      
      // Only refresh if token is expired or will expire within 30 seconds
      if (timeUntilExpiry.isNegative || timeUntilExpiry.inSeconds < 30) {
        debugPrint('🚨 [TOKEN REFRESH] Token expiring soon (${timeUntilExpiry.inSeconds}s remaining), refreshing in 30 sec...');
        final refreshed = await refreshToken();
        if (!refreshed) {
          debugPrint('❌ [TOKEN REFRESH] Periodic token refresh failed - stopping timer');
          _stopPeriodicTokenRefresh();
        } else {
          debugPrint('✅ [TOKEN REFRESH] Periodic token refresh completed successfully');
        }
      } else {
        debugPrint('✅ [TOKEN REFRESH] Token still valid, no refresh needed (${minutesLeft}m ${secondsLeft}s remaining)');
      }
    });
    
    debugPrint('✅ [TOKEN REFRESH] Started periodic token refresh (every 2 minutes)');
  }

  /// Stop periodic token refresh
  void _stopPeriodicTokenRefresh() {
    if (_tokenRefreshTimer != null) {
      debugPrint('🛑 [TOKEN REFRESH] Stopping periodic token refresh timer');
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = null;
      debugPrint('✅ [TOKEN REFRESH] Periodic token refresh timer stopped');
    }
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

