import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _phoneFullNumber = '';

  void _handleInitiateOtp() async {
    debugPrint('Login: Starting OTP initiation for $_phoneFullNumber');
    if (_formKey.currentState?.validate() ?? false) {
      debugPrint('Login: Form validated, calling notifier...');
      final notifier = ref.read(authStateProvider.notifier);
      await notifier.initiate_otp_with_prefix(
            _phoneFullNumber,
          );
      
      if (!mounted) {
        debugPrint('Login: Widget not mounted after await (expected if router moved us)');
        return;
      }

      final authState = ref.read(authStateProvider);
      debugPrint('Login: Post-auth status: ${authState.status}');
      
      // Navigation is now handled by the router's redirect logic,
      // but we add this fail-safe for immediate response.
      if (authState.status == AuthStatus.otpSent) {
        debugPrint('Login: Navigating to verify-otp (Manual fail-safe)');
        context.go('/verify-otp');
      } else if (authState.status == AuthStatus.error) {
        debugPrint('Login: Error state: ${authState.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authState.errorMessage ?? 'Failed to send OTP')),
        );
      }
    } else {
      debugPrint('Login: Form validation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authStateProvider.select((s) => s.status));
    final isLoading = status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.security_rounded, size: 80, color: Color(0xFF2166EE)),
                const SizedBox(height: 32),
                Text(
                  'Secure Access',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your phone number to receive a secure login code',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(),
                    ),
                    counterText: '',
                  ),
                  initialCountryCode: WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'US',
                  onChanged: (phone) {
                    _phoneFullNumber = phone.completeNumber;
                  },
                  onCountryChanged: (country) {
                    print('Country changed to: ${country.name}');
                  },
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _handleInitiateOtp(),
                  validator: (v) {
                    if (v == null || v.number.isEmpty) {
                      return 'Enter phone number';
                    }
                    try {
                      if (!v.isValidNumber()) {
                        return 'Invalid phone number length';
                      }
                    } catch (_) {}
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleInitiateOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2166EE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.read(authStateProvider.notifier).devSkip();
                    context.go('/chats');
                  },
                  child: const Text(
                    'Skip Login (Dev Only)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'By continuing, you agree to our secure messaging terms.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
