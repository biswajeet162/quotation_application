import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sync_logs_service.dart';
import '../widgets/page_header.dart';

class SyncLogsPage extends StatefulWidget {
  const SyncLogsPage({super.key});

  @override
  State<SyncLogsPage> createState() => SyncLogsPageState();
}

class SyncLogsPageState extends State<SyncLogsPage> {
  final SyncLogsService _logsService = SyncLogsService.instance;
  List<SyncLog> _logs = [];
  bool _isLoading = true;
  SyncLogType? _filterType;
  int _totalLogs = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // Listen for new log entries
    _logsService.onLogAdded = () {
      if (mounted) {
        _loadLogs();
      }
    };
  }
  
  @override
  void dispose() {
    _logsService.onLogAdded = null;
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh logs when page becomes visible
    _loadLogs();
  }

  void reloadData() {
    if (mounted) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _logsService.getLogs(type: _filterType, limit: 500);
      final totalCount = await _logsService.getLogCount();
      if (mounted) {
        setState(() {
          _logs = logs;
          _totalLogs = totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: Text(_filterType == null
            ? 'Are you sure you want to clear all logs?'
            : 'Are you sure you want to clear ${_filterType == SyncLogType.push ? "push" : "pull"} logs?'),
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logsService.clearLogs(type: _filterType);
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(title: 'Sync Monitor'),
          // Filter and Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                // Filter Buttons
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Push', SyncLogType.push),
                const SizedBox(width: 8),
                _buildFilterChip('Pull', SyncLogType.pull),
                const Spacer(),
                // Stats
                Text(
                  'Total: $_totalLogs',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                // Clear Button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear logs',
                  onPressed: _logs.isEmpty ? null : _clearLogs,
                  color: Colors.red,
                ),
                // Refresh Button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _loadLogs,
                ),
              ],
            ),
          ),
          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sync logs found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildLogCard(_logs[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SyncLogType? type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? type : null;
        });
        _loadLogs();
      },
      selectedColor: type == SyncLogType.push
          ? Colors.red.withOpacity(0.2)
          : type == SyncLogType.pull
              ? Colors.green.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
      checkmarkColor: type == SyncLogType.push
          ? Colors.red
          : type == SyncLogType.pull
              ? Colors.green
              : Colors.blue,
    );
  }

  Widget _buildLogCard(SyncLog log) {
    final isPush = log.type == SyncLogType.push;
    final color = isPush ? Colors.red : Colors.green;
    final icon = isPush ? Icons.arrow_upward : Icons.arrow_downward;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: log.success ? color.withOpacity(0.3) : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (log.success ? color : Colors.red).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (log.success ? color : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      log.success ? icon : Icons.error_outline,
                      color: log.success ? color : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Type and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isPush ? 'PUSH' : 'PULL',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: log.success ? color : Colors.red,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.success
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.success ? 'SUCCESS' : 'FAILED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: log.success ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(log.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Item Count Badge
                  if (log.itemCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${log.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Error Message (if any)
              if (log.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

