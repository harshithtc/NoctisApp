import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../data/models/message.dart';
import '../../../data/services/offline_service.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final OfflineService _offlineService = OfflineService();

  // Overview
  double _cacheSize = 0.0;

  // Breakdown
  int _cachedMessagesCount = 0;
  int _queuedMessagesCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    setState(() => _isLoading = true);

    // Size (heuristic from OfflineService)
    final size = await _offlineService.getCacheSize();

    // Counts (read boxes directly)
    int cached = 0;
    int queued = 0;
    try {
      final cachedBox = await Hive.openBox<Message>(OfflineService.messagesBox);
      cached = cachedBox.length;
      final queueBox = await Hive.openBox<Message>(OfflineService.queueBox);
      queued = queueBox.length;
    } catch (_) {
      // ignore read errors; keep counts at 0
    }

    if (!mounted) return;
    setState(() {
      _cacheSize = size;
      _cachedMessagesCount = cached;
      _queuedMessagesCount = queued;
      _isLoading = false;
    });
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text('This will delete cached messages, queued messages, and user cache.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineService.clearAllCache();
      await _loadStorageStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All cache cleared')));
      }
    }
  }

  Future<void> _clearMessageCacheOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Message Cache'),
        content: const Text('This will delete all locally cached messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineService.clearCachedMessages();
      await _loadStorageStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message cache cleared')));
      }
    }
  }

  Future<void> _clearQueueOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Message Queue'),
        content: const Text('This will delete all messages waiting to be sent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _offlineService.clearQueue();
      await _loadStorageStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue cleared')));
      }
    }
  }

  Color _sizeColor(ThemeData theme) {
    // Simple severity coloring based on size
    if (_cacheSize >= 20) return Colors.redAccent;
    if (_cacheSize >= 5) return theme.colorScheme.primary;
    return theme.textTheme.bodyMedium?.color ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStorageStats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Overview
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Cache Size'),
                    subtitle: Text(
                      '${_cacheSize.toStringAsFixed(2)} MB',
                      style: TextStyle(color: _sizeColor(theme), fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadStorageStats,
                    ),
                  ),

                  // Breakdown
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Breakdown', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: const Text('Cached messages'),
                    subtitle: Text('$_cachedMessagesCount item(s)'),
                    trailing: TextButton(
                      onPressed: _clearMessageCacheOnly,
                      child: const Text('Clear'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.outgoing_mail),
                    title: const Text('Queued messages'),
                    subtitle: Text('$_queuedMessagesCount item(s)'),
                    trailing: TextButton(
                      onPressed: _clearQueueOnly,
                      child: const Text('Clear'),
                    ),
                  ),

                  const Divider(),

                  // Clear all
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Clear All Cache', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('Deletes cached messages, queue, and user cache'),
                    onTap: _clearAllCache,
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'Note: Cache includes locally stored messages and queued messages for offline sending.',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
