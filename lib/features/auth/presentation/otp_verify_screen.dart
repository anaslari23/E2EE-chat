import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'providers/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _handleVerify(String code) async {
    final notifier = ref.read(authStateProvider.notifier);
    await notifier.completeVerification(code);
    
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    // Navigation is now handled by the router's redirect logic
    if (authState.status == AuthStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.errorMessage ?? 'Verification failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final phoneNumber = authState.phoneNumber ?? 'your number';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Number', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.mark_email_unread_outlined, size: 100, color: Color(0xFF2166EE)),
                const SizedBox(height: 40),
                Text(
                  'Verification Code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                    children: [
                      const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                      TextSpan(
                        text: phoneNumber,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 50,
                    fieldWidth: 45,
                    activeFillColor: Colors.white,
                    inactiveFillColor: const Color(0xFFF1F5F9),
                    selectedFillColor: Colors.white,
                    activeColor: const Color(0xFF2166EE),
                    inactiveColor: const Color(0xFFE2E8F0),
                    selectedColor: const Color(0xFF2166EE),
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  backgroundColor: Colors.transparent,
                  enableActiveFill: true,
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  onCompleted: _handleVerify,
                  onChanged: (value) {},
                  beforeTextPaste: (text) => true,
                ),
                const SizedBox(height: 40),
                if (isLoading)
                  const CircularProgressIndicator(color: Color(0xFF2166EE))
                else ...[
                  TextButton(
                    onPressed: () {
                      _codeController.clear();
                      context.go('/login');
                    },
                    child: const Text(
                      'Incorrect number?',
                      style: TextStyle(color: Color(0xFF2166EE), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Resend logic could be added here
                    },
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
