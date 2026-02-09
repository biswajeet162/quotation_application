import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/auto_sync_service.dart';
import '../services/desktop_oauth_service.dart';

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

class _PageHeaderState extends State<PageHeader> with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  int _syncCount = 0;
  AnimationController? _rotationController;
  bool _isGoogleDriveSignedIn = false;
  bool _showGreenRotation = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Check Google Drive status
    _checkGoogleDriveStatus();
    // Start periodic check to update status
    _startPeriodicCheck();
    
    // Listen to auto-sync state changes (only pull for the sync icon)
    AutoSyncService.instance.onPullStateChanged = () {
      if (mounted && _rotationController != null) {
        setState(() {
          _isSyncing = AutoSyncService.instance.isPulling;
          _syncCount = AutoSyncService.instance.pullCount;
        });
        if (_isSyncing) {
          _rotationController!.repeat();
        } else {
          _rotationController!.stop();
          _rotationController!.reset();
        }
      }
    };
    // Initialize state
    _isSyncing = AutoSyncService.instance.isPulling;
    _syncCount = AutoSyncService.instance.pullCount;
    
    if (_isSyncing) {
      _rotationController!.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController?.dispose();
    AutoSyncService.instance.onPullStateChanged = null;
    super.dispose();
  }

  Future<void> _checkGoogleDriveStatus() async {
    try {
      final googleAuth = GoogleAuthService.instance;
      // Load stored tokens first to ensure status is up to date
      await googleAuth.loadStoredTokens();
      
      // For desktop platforms, check DesktopOAuthService directly
      // For mobile, check GoogleAuthService
      bool isSignedIn;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Check DesktopOAuthService directly after loading tokens
        isSignedIn = DesktopOAuthService.instance.isSignedIn;
      } else {
        // For mobile, use GoogleAuthService
        isSignedIn = googleAuth.isSignedIn;
      }
      
      if (mounted) {
        setState(() {
          _isGoogleDriveSignedIn = isSignedIn;
        });
      }
    } catch (e) {
      // If there's an error, assume not signed in
      if (mounted) {
        setState(() {
          _isGoogleDriveSignedIn = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh Google Drive status when page becomes visible
    _checkGoogleDriveStatus();
  }

  // Periodic check to update Google Drive status (less frequent to avoid flooding)
  void _startPeriodicCheck() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkGoogleDriveStatus();
        _startPeriodicCheck(); // Schedule next check
      }
    });
  }

  Future<void> _syncNow() async {
    final isAuthenticated = await GoogleAuthService.instance.loadStoredTokens();
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

    // Start green rotation animation for 2 seconds immediately
    if (mounted && _rotationController != null) {
      setState(() {
        _showGreenRotation = true;
      });
      // Start rotation immediately
      if (!_rotationController!.isAnimating) {
        _rotationController!.repeat();
      }
      
      // Stop green rotation after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showGreenRotation = false;
          });
          // Only stop if not actually syncing
          if (!_isSyncing && _rotationController != null) {
            _rotationController!.stop();
            _rotationController!.reset();
          }
        }
      });
    }

    // Trigger immediate pull for quotations, users, and companies
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
                    const SizedBox(width: 8),
                    // Google Drive Status Dot
                    Tooltip(
                      message: _isGoogleDriveSignedIn 
                          ? 'Google Drive: Signed In' 
                          : 'Google Drive: Not Signed In',
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isGoogleDriveSignedIn ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Single Sync Icon - Click to pull quotations, users, and companies
                    Tooltip(
                      message: _isSyncing || _showGreenRotation
                          ? 'Syncing $_syncCount item(s) from Google Drive...' 
                          : 'Sync: Pull quotations, users, and companies from Google Drive',
                      child: GestureDetector(
                        onTap: (_isSyncing || _showGreenRotation) ? null : _syncNow,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _rotationController != null
                                ? AnimatedBuilder(
                                    animation: _rotationController!,
                                    builder: (context, child) {
                                      final isRotating = _isSyncing || _showGreenRotation;
                                      final iconColor = _showGreenRotation 
                                          ? Colors.green 
                                          : (_isSyncing ? Colors.blue : Colors.grey);
                                      return Transform.rotate(
                                        angle: isRotating ? _rotationController!.value * 2 * 3.14159 : 0,
                                        child: Icon(
                                          Icons.sync,
                                          color: iconColor,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.sync,
                                    color: _showGreenRotation 
                                        ? Colors.green 
                                        : (_isSyncing ? Colors.blue : Colors.grey),
                                    size: 20,
                                  ),
                            if ((_isSyncing || _showGreenRotation) && _syncCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _showGreenRotation ? Colors.green : Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_syncCount',
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

