/// Example OAuth Configuration File
/// 
/// Copy this file to oauth_config.dart and fill in your credentials
/// 
/// DO NOT commit oauth_config.dart to version control
class OAuthConfig {
  static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
  static const String clientSecret = '';
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];
  static const int callbackPort = 8080;
  static String get redirectUri => 'http://localhost:$callbackPort/callback';
  static const String authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  
  static bool get isConfigured {
    return clientId.isNotEmpty && 
           !clientId.contains('YOUR_CLIENT_ID_HERE') &&
           clientId.contains('.apps.googleusercontent.com');
  }
}

