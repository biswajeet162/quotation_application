import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/auto_sync_service.dart';

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
  bool _isPulling = false;
  bool _isPushing = false;
  int _pushCount = 0;
  int _pullCount = 0;

  @override
  void initState() {
    super.initState();
    // Listen to auto-sync state changes
    AutoSyncService.instance.onPushStateChanged = () {
      if (mounted) {
        setState(() {
          _isPushing = AutoSyncService.instance.isPushing;
          _pushCount = AutoSyncService.instance.pushCount;
        });
      }
    };
    AutoSyncService.instance.onPullStateChanged = () {
      if (mounted) {
        setState(() {
          _isPulling = AutoSyncService.instance.isPulling;
          _pullCount = AutoSyncService.instance.pullCount;
        });
      }
    };
    // Initialize state
    _isPushing = AutoSyncService.instance.isPushing;
    _isPulling = AutoSyncService.instance.isPulling;
    _pushCount = AutoSyncService.instance.pushCount;
    _pullCount = AutoSyncService.instance.pullCount;
  }

  @override
  void dispose() {
    AutoSyncService.instance.onPushStateChanged = null;
    AutoSyncService.instance.onPullStateChanged = null;
    super.dispose();
  }

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

    // Trigger immediate pull
    await AutoSyncService.instance.performPull();
    
    if (mounted) {
      final pullCount = AutoSyncService.instance.pullCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pullCount > 0 
              ? 'Sync completed! Downloaded $pullCount item(s).'
              : 'Sync completed!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
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
                    // PUSH Icon (Red) - Shows when data is being pushed
                    Tooltip(
                      message: _isPushing 
                          ? 'Pushing $_pushCount item(s) to Google Drive...' 
                          : 'PUSH: Auto-uploads changes',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isPushing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                  ),
                                )
                              : Icon(
                                  Icons.sync,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                          if (_isPushing && _pushCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_pushCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PULL Icon (Green) - Shows when data is being pulled
                    Tooltip(
                      message: _isPulling 
                          ? 'Pulling $_pullCount item(s) from Google Drive...' 
                          : 'PULL: Fetch updates (click to sync now)',
                      child: GestureDetector(
                        onTap: _isPulling ? null : _syncNow,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isPulling
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  )
                                : Icon(
                                    Icons.sync,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                            if (_isPulling && _pullCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_pullCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

