import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';

class GoogleDriveAuthHelper {
  /// Checks if Google Drive is signed in
  static Future<bool> checkAndShowNotificationIfNotSignedIn(BuildContext context) async {
    final googleAuth = GoogleAuthService.instance;
    // Try to load stored tokens first
    await googleAuth.loadStoredTokens();
    final isSignedIn = googleAuth.isSignedIn;
    
    if (!isSignedIn) {
      _showSignInRequiredNotification(context);
      return false;
    }
    return true;
  }

  /// Shows a notification dialog requiring Google Drive sign-in
  static void _showSignInRequiredNotification(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Google Drive Sign-In Required'),
            ),
          ],
        ),
        content: const Text(
          'You need to sign in to Google Drive first to perform this operation. '
          'Please sign in to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _handleSignIn(context);
            },
            icon: const Icon(Icons.login, size: 20),
            label: const Text('Sign In to Google Drive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Handles Google Drive sign-in
  static Future<void> _handleSignIn(BuildContext context) async {
    try {
      final googleAuth = GoogleAuthService.instance;
      final success = await googleAuth.signIn();
      
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in to Google Drive'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sign in to Google Drive. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

