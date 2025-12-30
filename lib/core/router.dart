import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/profile_setup_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/starred_messages_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final status = authState.status;
      final loggingIn = state.matchedLocation == '/login' || 
                        state.matchedLocation == '/verify-otp' ||
                        state.matchedLocation == '/profile-setup';

      if (status == AuthStatus.authenticated) {
        if (loggingIn) return '/chats';
      } else if (status == AuthStatus.needsSetup) {
        if (state.matchedLocation != '/profile-setup') return '/profile-setup';
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
    ],
  );
});
