import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
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

      // Exchange authorization code for tokens
    //   final tokenResponse = await http.post(
    //     Uri.parse(OAuthConfig.tokenEndpoint),
    //     headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    //     body: {
    //       'client_id': OAuthConfig.clientId,
    //       'code': authCode,
    //       'code_verifier': codeVerifier,
    //       'redirect_uri': OAuthConfig.redirectUri,
    //       'grant_type': 'authorization_code',
    //     },
    //   );
    // Exchange authorization code for tokens
        final body = <String, String>{
        'client_id': OAuthConfig.clientId,
        'code': authCode,
        'code_verifier': codeVerifier,
        'redirect_uri': OAuthConfig.redirectUri,
        'grant_type': 'authorization_code',
        };

        // Add client_secret only if it's configured (some OAuth clients require it)
        if (OAuthConfig.clientSecret.isNotEmpty) {
        body['client_secret'] = OAuthConfig.clientSecret;
        }

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
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // Store tokens
      await _storage.write(key: _accessTokenKey, value: _accessToken);
      if (_refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: _refreshToken);
      }
      await _storage.write(
        key: _expiryKey,
        value: _tokenExpiry!.toIso8601String(),
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> loadStoredTokens() async {
    try {
      final storedToken = await _storage.read(key: _accessTokenKey);
      final storedExpiry = await _storage.read(key: _expiryKey);
      _refreshToken = await _storage.read(key: _refreshTokenKey);

      if (storedToken == null || storedExpiry == null) {
        return false;
      }

      final expiry = DateTime.parse(storedExpiry);
      if (expiry.isBefore(DateTime.now())) {
        return await refreshToken();
      }

      _accessToken = storedToken;
      _tokenExpiry = expiry;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refreshToken() async {
    try {
      if (_refreshToken == null) {
        final stored = await _storage.read(key: _refreshTokenKey);
        if (stored == null) {
          return false;
        }
        _refreshToken = stored;
      }

      final tokenResponse = await http.post(
        Uri.parse(OAuthConfig.tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': OAuthConfig.clientId,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (tokenResponse.statusCode != 200) {
        return false;
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      _accessToken = tokenData['access_token'] as String;
      
      final expiresIn = tokenData['expires_in'] as int;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      await _storage.write(key: _accessTokenKey, value: _accessToken);
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

  Future<void> signOut() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _expiryKey);
      await _storage.delete(key: _codeVerifierKey);
      _accessToken = null;
      _tokenExpiry = null;
      _refreshToken = null;
    } catch (e) {
      // Ignore errors
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

