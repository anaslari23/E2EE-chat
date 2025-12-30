import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _biometricEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bio = ref.read(biometricServiceProvider);
    final enabled = await bio.isLockEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final bio = ref.read(biometricServiceProvider);
    
    if (value) {
      // Authenticate before enabling
      final success = await bio.authenticate();
      if (!success) return;
    }

    await bio.setLockEnabled(value);
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy & Security"),
      ),
      body: ListView(
        children: [
          _buildSectionHeader("Security"),
          SwitchListTile(
            title: const Text("App Lock"),
            subtitle: const Text("Require biometric to unlock the app"),
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
            secondary: const Icon(Icons.fingerprint),
          ),
          const Divider(),
          _buildSectionHeader("Chat Privacy"),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text("Default Disappearing Timer"),
            subtitle: const Text("Off"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement default timer setting
            },
          ),
          const Divider(),
          _buildSectionHeader("Linked Devices"),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text("Manage Devices"),
            subtitle: const Text("View and remove linked devices"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/linked-devices');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2166EE),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
