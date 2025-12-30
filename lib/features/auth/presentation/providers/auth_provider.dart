import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/user.dart';
import '../../../../core/providers.dart';

enum AuthStatus { initial, loading, otpSent, needsSetup, authenticated, error }

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
  factory AuthState.needsSetup(AuthenticatedUser user) => 
      AuthState(status: AuthStatus.needsSetup, user: user);
  factory AuthState.authenticated(AuthenticatedUser user) => 
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.error(String message) => 
      AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(AuthState.initial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final userJson = await storage.read(key: 'auth_user');
      
      if (userJson != null) {
        final user = AuthenticatedUser.fromJson(jsonDecode(userJson));
        await _initializeSecurityAndConnect(user);
        state = AuthState.authenticated(user);
      }
    } catch (e) {
      print('Auto-login failed: $e');
      state = AuthState.initial();
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_user');
    state = AuthState.initial();
    // In a real app, also close WS and clear Signal state
    ref.read(authProvider.notifier).state = null;
  }

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

  Future<void> initiate_otp_with_prefix(String fullNumber) async {
    state = AuthState.loading();
    try {
      final api = ref.read(apiServiceProvider);
      await api.requestOtp(fullNumber);
      state = AuthState.otpSent(fullNumber);
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
      
      if (user.needsSetup) {
        state = AuthState.needsSetup(user);
      } else {
        await _initializeSecurityAndConnect(user);
        state = AuthState.authenticated(user);
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> updateProfile(String username) async {
    final user = state.user;
    if (user == null) return;

    state = AuthState.loading();
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.updateProfile(user.id, username);
      
      // Create new user object with updated username
      final updatedUser = AuthenticatedUser(
        id: user.id,
        username: response['username'],
        accessToken: user.accessToken,
        needsSetup: false,
      );

      await _initializeSecurityAndConnect(updatedUser);
      state = AuthState.authenticated(updatedUser);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> devSkip() async {
    // Simulate a successful login with User ID 1 for development
    final user = AuthenticatedUser(
      id: 1, 
      username: 'DevUser', 
      accessToken: 'dev_token'
    );
    
    state = AuthState.authenticated(user);

    // Try to initialize security but don't fail if backend is down
    try {
      await _initializeSecurityAndConnect(user);
    } catch (e) {
      print('DevSkip: Security init failed (expected if backend down): $e');
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
    ws.connect(user.id, deviceId, user.accessToken);
    
    // 4. Persist Session
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'auth_user', value: jsonEncode(user.toJson()));

    // 5. Register Push Token
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await api.registerPushToken(user.id, deviceId, token);
        }
      }
    } catch (e) {
      print("Push token registration failed: $e");
    }

    // Update global auth state
    ref.read(authProvider.notifier).state = user.id;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
