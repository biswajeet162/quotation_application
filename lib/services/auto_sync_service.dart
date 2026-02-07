import 'dart:async';
import 'package:flutter/foundation.dart';
import 'google_auth_service.dart';
import 'drive_sync_service.dart';
import 'sync_logs_service.dart';

/// Service for automatic push and pull synchronization
class AutoSyncService {
  static final AutoSyncService instance = AutoSyncService._init();
  AutoSyncService._init();

  Timer? _pullTimer;
  bool _isPushing = false;
  bool _isPulling = false;
  int _pushCount = 0;
  int _pullCount = 0;
  
  // Configuration
  Duration _pullInterval = const Duration(minutes: 5);
  
  // Callbacks for UI updates
  VoidCallback? onPushStateChanged;
  VoidCallback? onPullStateChanged;

  /// Get current pull interval
  Duration get pullInterval => _pullInterval;

  /// Set pull interval (minimum 1 minute)
  void setPullInterval(Duration interval) {
    if (interval.inMinutes < 1) {
      _pullInterval = const Duration(minutes: 1);
    } else {
      _pullInterval = interval;
    }
    _restartPullTimer();
  }

  /// Check if push is in progress
  bool get isPushing => _isPushing;

  /// Check if pull is in progress
  bool get isPulling => _isPulling;

  /// Get current push count
  int get pushCount => _pushCount;

  /// Get current pull count
  int get pullCount => _pullCount;

  /// Start automatic pull timer
  void startAutoPull() {
    _stopAutoPull();
    if (!GoogleAuthService.instance.isSignedIn) {
      return;
    }
    _pullTimer = Timer.periodic(_pullInterval, (_) => _performPull());
  }

  /// Stop automatic pull timer
  void stopAutoPull() {
    _stopAutoPull();
  }

  void _stopAutoPull() {
    _pullTimer?.cancel();
    _pullTimer = null;
  }

  void _restartPullTimer() {
    if (_pullTimer != null) {
      startAutoPull();
    }
  }

  /// Perform automatic push for a single record
  /// Returns true if push was successful or skipped, false on error
  Future<bool> pushSingleRecord({
    required String table,
    required int? recordId,
  }) async {
    // Skip if recordId is null
    if (recordId == null) {
      return true;
    }

    if (_isPushing) {
      // Skip if already pushing to avoid conflicts
      return true;
    }

    if (!GoogleAuthService.instance.isSignedIn) {
      return false;
    }

    _isPushing = true;
    _pushCount = 0;
    onPushStateChanged?.call();

    try {
      final result = await DriveSyncService.instance.syncAll(forceFullSync: false);
      _pushCount = result.usersSynced + result.companiesSynced + result.quotationsSynced + result.myCompanySynced;
      
      // Log the push operation
      await SyncLogsService.instance.addLog(SyncLog(
        type: SyncLogType.push,
        timestamp: DateTime.now(),
        message: 'Pushed ${result.usersSynced} user(s), ${result.companiesSynced} company(ies), ${result.quotationsSynced} quotation(s), ${result.myCompanySynced} my_company',
        itemCount: _pushCount,
        success: result.success,
        error: result.errors.isNotEmpty ? result.errors.join('; ') : null,
      ));
      
      onPushStateChanged?.call();
      return result.success;
    } catch (e) {
      debugPrint('Auto push failed: $e');
      
      // Log the error
      await SyncLogsService.instance.addLog(SyncLog(
        type: SyncLogType.push,
        timestamp: DateTime.now(),
        message: 'Push operation failed',
        itemCount: 0,
        success: false,
        error: e.toString(),
      ));
      
      return false;
    } finally {
      _isPushing = false;
      onPushStateChanged?.call();
      // Reset count after a short delay to let user see it
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isPushing) {
          _pushCount = 0;
          onPushStateChanged?.call();
        }
      });
    }
  }

  /// Perform automatic pull
  Future<void> _performPull() async {
    if (_isPulling) {
      return; // Skip if already pulling
    }

    if (!GoogleAuthService.instance.isSignedIn) {
      return;
    }

    _isPulling = true;
    _pullCount = 0;
    onPullStateChanged?.call();

    try {
      final result = await DriveSyncService.instance.syncAll(forceFullSync: false);
      _pullCount = result.usersDownloaded + result.companiesDownloaded + result.quotationsDownloaded;
      
      // Log the pull operation
      await SyncLogsService.instance.addLog(SyncLog(
        type: SyncLogType.pull,
        timestamp: DateTime.now(),
        message: 'Pulled ${result.usersDownloaded} user(s), ${result.companiesDownloaded} company(ies), ${result.quotationsDownloaded} quotation(s)',
        itemCount: _pullCount,
        success: result.success,
        error: result.errors.isNotEmpty ? result.errors.join('; ') : null,
      ));
      
      onPullStateChanged?.call();
    } catch (e) {
      debugPrint('Auto pull failed: $e');
      
      // Log the error
      await SyncLogsService.instance.addLog(SyncLog(
        type: SyncLogType.pull,
        timestamp: DateTime.now(),
        message: 'Pull operation failed',
        itemCount: 0,
        success: false,
        error: e.toString(),
      ));
    } finally {
      _isPulling = false;
      onPullStateChanged?.call();
      // Reset count after a short delay to let user see it
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isPulling) {
          _pullCount = 0;
          onPullStateChanged?.call();
        }
      });
    }
  }

  /// Perform manual pull (called on app startup or manual sync)
  Future<void> performPull() async {
    await _performPull();
  }

  /// Cleanup
  void dispose() {
    _stopAutoPull();
    onPushStateChanged = null;
    onPullStateChanged = null;
  }
}

