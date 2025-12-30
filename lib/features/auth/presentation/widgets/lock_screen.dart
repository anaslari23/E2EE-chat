import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  final Widget child;
  const LockScreen({super.key, required this.child});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _reLockIfEnabled();
    }
  }

  Future<void> _reLockIfEnabled() async {
    final bio = ref.read(biometricServiceProvider);
    if (await bio.isLockEnabled()) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _checkLock() async {
    final bio = ref.read(biometricServiceProvider);
    final enabled = await bio.isLockEnabled();
    
    if (!enabled) {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _isChecking = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isChecking = false);
    _authenticate();
  }

  Future<void> _authenticate() async {
    final bio = ref.read(biometricServiceProvider);
    final success = await bio.authenticate();
    if (success && mounted) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF2166EE)),
            const SizedBox(height: 24),
            const Text(
              "App Locked",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Authentication required to proceed",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text("Unlock Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2166EE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
