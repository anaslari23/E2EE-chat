import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/profile_setup_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/starred_messages_screen.dart';
import '../features/chat/presentation/group_setup_screen.dart';
import '../features/chat/presentation/screens/security_settings_screen.dart';
import '../features/chat/presentation/screens/linked_devices_screen.dart';
import '../features/chat/presentation/screens/storage_settings_screen.dart';
import '../features/chat/presentation/screens/appearance_settings_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      debugPrint('RouterNotifier: Auth state changed from ${previous?.status} to ${next.status}');
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final status = authState.status;
      final location = state.matchedLocation;
      
      debugPrint('Router: Redirect check - Status: $status, Location: $location');

      final loggingIn = location == '/login' || 
                        location == '/verify-otp' ||
                        location == '/profile-setup';

      if (status == AuthStatus.authenticated) {
        if (loggingIn) return '/chats';
      } else if (status == AuthStatus.needsSetup) {
        if (location != '/profile-setup') return '/profile-setup';
      } else if (status == AuthStatus.otpSent) {
        if (location == '/login') {
          debugPrint('Router: Moving from login to verify-otp for status otpSent');
          return '/verify-otp';
        }
      } else {
        if (!loggingIn) return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatScreen(id: id);
        },
      ),
      GoRoute(
        path: '/starred',
        builder: (context, state) => const StarredMessagesScreen(),
      ),
      GoRoute(
        path: '/group-setup',
        builder: (context, state) => const GroupSetupScreen(),
      ),
      GoRoute(
        path: '/security-settings',
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/linked-devices',
        builder: (context, state) => const LinkedDevicesScreen(),
      ),
      GoRoute(
        path: '/storage-settings',
        builder: (context, state) => const StorageSettingsScreen(),
      ),
      GoRoute(
        path: '/appearance-settings',
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
    ],
  );
});
