import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user.dart';
import '../../../../core/providers.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, error }

class AuthState {
  final AuthStatus status;
  final AuthenticatedUser? user;
  final String? phoneNumber;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.phoneNumber,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.otpSent(String phone) => 
      AuthState(status: AuthStatus.otpSent, phoneNumber: phone);
  factory AuthState.authenticated(AuthenticatedUser user) => 
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.error(String message) => 
      AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(AuthState.initial());

  Future<void> initiateOtp(String phoneNumber) async {
    state = AuthState.loading();
    try {
      final api = ref.read(apiServiceProvider);
      await api.requestOtp(phoneNumber);
      state = AuthState.otpSent(phoneNumber);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> completeVerification(String code) async {
    final phone = state.phoneNumber;
    if (phone == null) return;

    state = AuthState.loading();
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.verifyOtp(phone, code);
      final user = AuthenticatedUser.fromJson(response);
      
      await _initializeSecurityAndConnect(user);
      
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> devSkip() async {
    state = AuthState.loading();
    try {
      // Simulate a successful login with User ID 1 for development
      final user = AuthenticatedUser(
        id: 1, 
        username: 'DevUser', 
        accessToken: 'dev_token'
      );
      
      await _initializeSecurityAndConnect(user);
      
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> _initializeSecurityAndConnect(AuthenticatedUser user) async {
    final deviceId = 1; // Simplified: Dynamic device IDs in production
    
    // 1. Initialize Signal context
    final signal = ref.read(signalServiceProvider);
    await signal.initialize(user.username, deviceId);
    
    // 2. Upload Pre-Key Bundle
    final bundle = await signal.getPreKeyBundle();
    final api = ref.read(apiServiceProvider);
    await api.uploadPreKeyBundle(user.id, deviceId, bundle);
    
    // 3. Connect WebSocket
    final ws = ref.read(webSocketServiceProvider);
    ws.connect(user.id, deviceId);
    
    // Update global auth state
    ref.read(authProvider.notifier).state = user.id;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
