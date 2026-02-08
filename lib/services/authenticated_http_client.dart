import 'package:http/http.dart' as http;
import 'dart:async';
import 'google_auth_service.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;

  AuthenticatedHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Get a fresh token for each request to handle token expiration
    // getValidAccessToken() automatically refreshes expired tokens
    final token = await GoogleAuthService.instance.getValidAccessToken();
    if (token == null) {
      throw Exception('Not authenticated with Google');
    }
    
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

