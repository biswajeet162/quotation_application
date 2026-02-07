import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/drive_sync_service.dart';

class PageHeader extends StatefulWidget {
  final String title;
  final int? count;
  final Widget? actionButton;
  final bool showWelcome;

  const PageHeader({
    super.key,
    required this.title,
    this.count,
    this.actionButton,
    this.showWelcome = true,
  });

  @override
  State<PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<PageHeader> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    final isAuthenticated = GoogleAuthService.instance.isSignedIn;
    if (!isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to Google Drive in Settings first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final result = await DriveSyncService.instance.syncAll();
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sync completed!\n'
                'Users: ${result.usersSynced} synced, ${result.usersDownloaded} downloaded\n'
                'Companies: ${result.companiesSynced} synced, ${result.companiesDownloaded} downloaded\n'
                'Quotations: ${result.quotationsSynced} synced, ${result.quotationsDownloaded} downloaded',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync completed with errors: ${result.errors.join(", ")}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final userName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (currentUser?.email ?? 'User');
    final isGoogleAuthenticated = GoogleAuthService.instance.isSignedIn;

    return Column(
      children: [
        // Welcome Header
        if (widget.showWelcome)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Welcome, $userName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sync Button
                    IconButton(
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            )
                          : Icon(
                              Icons.sync,
                              color: isGoogleAuthenticated ? Colors.green : Colors.grey,
                            ),
                      tooltip: isGoogleAuthenticated ? 'Sync with Google Drive' : 'Sign in to Google Drive in Settings',
                      onPressed: _isSyncing ? null : _syncNow,
                    ),
                    // Logout Button
                    IconButton(
                      icon: const Icon(Icons.logout),
                      color: Colors.red,
                      tooltip: 'Logout',
                      onPressed: () async {
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
                  ],
                ),
              ],
            ),
          ),
        // Page Title Header
        Container(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.count != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.count})',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.actionButton != null) widget.actionButton!,
            ],
          ),
        ),
      ],
    );
  }
}

