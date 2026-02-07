import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';
import '../models/my_company.dart';
import 'password_reset_page.dart';
import 'package:intl/intl.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  final String userEmail;

  const SettingsPage({
    super.key,
    required this.userEmail,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String? _lastSyncTime;
  bool _isAuthenticated = false;
  String? _googleAccountEmail;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _loadLastSyncTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status when page becomes visible
    _checkAuthStatus();
    _loadLastSyncTime();
  }

  Future<void> _checkAuthStatus() async {
    final googleAuth = GoogleAuthService.instance;
    // Try to load stored tokens first
    await googleAuth.loadStoredTokens();
    final isSignedIn = googleAuth.isSignedIn;
    final account = googleAuth.currentUser;
    
    // For desktop, we don't have account email from google_sign_in
    // We'll show authenticated status only
    if (mounted) {
      setState(() {
        _isAuthenticated = isSignedIn;
        _googleAccountEmail = account?.email ?? (isSignedIn ? 'Authenticated' : null);
      });
    }
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final driveService = GoogleDriveService.instance;
      final fileId = await driveService.findFileByName('last_sync.json', 'sync');
      if (fileId != null) {
        final content = await driveService.downloadFile(fileId);
        final data = jsonDecode(content) as Map<String, dynamic>;
        final timeStr = data['lastSync'] as String?;
        if (timeStr != null && mounted) {
          setState(() {
            _lastSyncTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(timeStr));
          });
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _signInToGoogle() async {
    setState(() => _isLoading = true);
    try {
      final success = await GoogleAuthService.instance.signIn();
      if (success && mounted) {
        await _checkAuthStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed in to Google Drive'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to sign in to Google Drive',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Make sure you have configured OAuth 2.0 Client ID in Google Cloud Console for desktop application.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOutFromGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out from Google Drive'),
        content: const Text('Are you sure you want to sign out from Google Drive? You will need to sign in again to sync data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await GoogleAuthService.instance.signOut();
        if (mounted) {
          await _checkAuthStatus();
          setState(() {
            _lastSyncTime = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out from Google Drive'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isAdmin = authService.isAdmin;

    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
            title: 'Settings',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.business),
                    title: const Text('My Company Details'),
                    subtitle: Text(MyCompany.name),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Company Name',
                              MyCompany.name,
                              Icons.business_outlined,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Address: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      MyCompany.address,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildInfoRow(
                              'GST',
                              MyCompany.gst,
                              Icons.receipt_outlined,
                            ),
                            _buildInfoRow(
                              'PAN',
                              MyCompany.pan,
                              Icons.badge_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Account Information'),
                    subtitle: Text(widget.userEmail),
                    children: [
                      if (authService.currentUser != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (authService.currentUser!.name.isNotEmpty)
                                _buildInfoRow(
                                  'Name',
                                  authService.currentUser!.name,
                                  Icons.person_outline,
                                ),
                              _buildInfoRow(
                                'Email',
                                authService.currentUser!.email,
                                Icons.email_outlined,
                              ),
                              if (authService.currentUser!.mobileNumber.isNotEmpty)
                                _buildInfoRow(
                                  'Mobile',
                                  authService.currentUser!.mobileNumber,
                                  Icons.phone_outlined,
                                ),
                              _buildInfoRow(
                                'Role',
                                authService.currentUser!.role.toUpperCase(),
                                Icons.badge_outlined,
                              ),
                              if (authService.currentUser!.createdBy != null)
                                _buildInfoRow(
                                  'Created By',
                                  authService.currentUser!.createdBy!,
                                  Icons.person_add_outlined,
                                ),
                              _buildInfoRow(
                                'Created At',
                                DateFormat('dd/MM/yyyy HH:mm').format(
                                  authService.currentUser!.createdAt,
                                ),
                                Icons.calendar_today_outlined,
                              ),
                              if (authService.currentUser!.lastLoginTime != null)
                                _buildInfoRow(
                                  'Last Login',
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    authService.currentUser!.lastLoginTime!,
                                  ),
                                  Icons.access_time_outlined,
                                )
                              else
                                _buildInfoRow('Last Login', 'Never', Icons.access_time_outlined),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Google Drive Sync - Admin Only
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: ExpansionTile(
                      leading: Icon(
                        _isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                        color: _isAuthenticated ? Colors.green : Colors.grey,
                      ),
                      title: const Text('Google Drive Sync'),
                      subtitle: Text(
                        _isAuthenticated
                            ? (_googleAccountEmail ?? 'Connected')
                            : 'Not connected',
                        style: TextStyle(
                          color: _isAuthenticated ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Authentication Status
                            Row(
                              children: [
                                Icon(
                                  _isAuthenticated ? Icons.check_circle : Icons.cancel,
                                  color: _isAuthenticated ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Status: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _isAuthenticated ? 'Authenticated' : 'Not Authenticated',
                                  style: TextStyle(
                                    color: _isAuthenticated ? Colors.green : Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (_isAuthenticated && _googleAccountEmail != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Google Account',
                                _googleAccountEmail!,
                                Icons.account_circle_outlined,
                              ),
                            ],
                            if (_lastSyncTime != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Last Sync',
                                _lastSyncTime!,
                                Icons.sync_outlined,
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            // Action Buttons
                            if (!_isAuthenticated) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _signInToGoogle,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  label: const Text('Sign In to Google Drive'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'This will open Chrome with your logged-in Gmail account and ask for consent to access Google Drive. After granting consent, the application will be able to push data to Google Drive.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ]
                            else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _signOutFromGoogle,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign Out from Google Drive'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('Reset Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PasswordResetPage(userEmail: widget.userEmail),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await authService.logout();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

