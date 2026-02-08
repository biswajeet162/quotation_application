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
  /// IMMEDIATELY pushes pending records to Drive (NO PULL)
  /// Returns true if push was successful or skipped, false on error
  Future<bool> pushSingleRecord({
    required String table,
    required int? recordId,
  }) async {
    // Skip if recordId is null
    if (recordId == null) {
      return true;
    }

    if (!GoogleAuthService.instance.isSignedIn) {
      return false;
    }

    // Don't block if already pushing - queue it or skip
    if (_isPushing) {
      // Wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isPushing) {
        // Still pushing, skip this one (will be picked up in next push)
        return true;
      }
    }

    _isPushing = true;
    _pushCount = 0;
    onPushStateChanged?.call();

    try {
      // PUSH ONLY - no pull
      final result = await DriveSyncService.instance.pushOnly(forceFullSync: false);
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
  /// PULLS ONLY from Drive to local DB (NO PUSH)
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
      // PULL ONLY - no push
      final result = await DriveSyncService.instance.pullOnly(forceFullSync: false);
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
  /// This ensures logs are created even for manual pulls
  Future<void> performPull() async {
    // If already pulling, wait for it to finish
    if (_isPulling) {
      // Wait for current pull to finish
      while (_isPulling) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    
    // Perform the pull (which will log)
    await _performPull();
  }

  /// Cleanup
  void dispose() {
    _stopAutoPull();
    onPushStateChanged = null;
    onPullStateChanged = null;
  }
}

