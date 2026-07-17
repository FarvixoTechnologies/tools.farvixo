import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/firebase/pending_deep_link.dart';
import '../features/ai/ai_assistant_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/devices_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../ui/splash/splash_screen.dart';
import '../features/tools/tool_detail_screen.dart';
import '../features/tools/tools_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// OAuth / magic-link return URI (`com.farvixo.app://login-callback?...`).
/// Must not be treated as a go_router page path.
bool _isAuthCallback(Uri uri) {
  if (uri.host == 'login-callback') return true;
  if (uri.path == '/login-callback' || uri.path.endsWith('/login-callback')) {
    return true;
  }
  final full = uri.toString();
  return full.contains('login-callback');
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    // Deep links like com.farvixo.app://login-callback/?code=... must not 404.
    redirect: (context, state) {
      if (_isAuthCallback(state.uri)) {
        // Supabase auth listener exchanges the code; send user into the app.
        return '/home';
      }
      final pending = PendingDeepLink.take();
      if (pending != null &&
          pending != state.matchedLocation &&
          pending.startsWith('/')) {
        return pending;
      }
      return null;
    },
    onException: (context, state, router) {
      if (_isAuthCallback(state.uri)) {
        router.go('/home');
        return;
      }
      // Unknown deep link / bad path → home instead of a hard crash screen.
      router.go('/home');
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Path-style callback (some platforms normalize the deep link this way).
      GoRoute(
        path: '/login-callback',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/downloads',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/devices',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/tool/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ToolDetailScreen(toolId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => ToolsScreen(
                initialCategoryId: state.uri.queryParameters['category'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/ai',
              builder: (context, state) => const AiAssistantScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
