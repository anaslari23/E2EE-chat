import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  int _cacheSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    setState(() => _isLoading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      int size = 0;
      if (await tempDir.exists()) {
        await for (final file in tempDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            size += await file.length();
          }
        }
      }
      if (mounted) {
        setState(() {
          _cacheSize = size;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error calculating storage: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final file in tempDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            await file.delete();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
      await _calculateStorage();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Data')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildUsageCard(),
                const SizedBox(height: 24),
                const Text(
                  'Media Auto-Download',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('When using mobile data'),
                  subtitle: const Text('Photos only'),
                  value: true,
                  onChanged: (val) {}, // TODO: Implement persistent setting
                ),
                SwitchListTile(
                  title: const Text('When connected on Wi-Fi'),
                  subtitle: const Text('All media'),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(),
                ListTile(
                  title: const Text('Clear Cache', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Frees up space by deleting temporary media files'),
                  trailing: Text(_formatSize(_cacheSize)),
                  onTap: _clearCache,
                ),
              ],
            ),
    );
  }

  Widget _buildUsageCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Total Cache Used',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _formatSize(_cacheSize),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
