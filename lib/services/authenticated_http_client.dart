import 'package:http/http.dart' as http;
import 'dart:async';

class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String _accessToken;

  AuthenticatedHttpClient(this._inner, this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

