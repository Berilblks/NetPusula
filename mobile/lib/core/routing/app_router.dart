import '../../features/statistics/presentation/statistics_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/home_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/preparation/application/preparation_controller.dart';
import '../../features/preparation/presentation/preparation_loading_screen.dart';
import '../../features/preparation/presentation/goal_screen.dart';

import '../../features/mock_exams/presentation/mock_exam_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen(preparationControllerProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, route) {
      final auth = ref.read(authControllerProvider);
      final path = route.uri.path;
      if (auth.status == AuthStatus.initializing ||
          auth.status == AuthStatus.startupError) {
        return path == '/splash' ? null : '/splash';
      }
      if (auth.status == AuthStatus.authenticated) {
        final preparation = ref.read(preparationControllerProvider);
        if (preparation.status == PreparationStatus.none) {
          return path == '/onboarding' ? null : '/onboarding';
        }
        if (preparation.status == PreparationStatus.ready) {
          return {'/home', '/goal/edit', '/statistics'}.contains(path) ||
                  path == '/mock-exams' ||
                  path.startsWith('/mock-exams/')
              ? null
              : '/home';
        }
        return path == '/preparation' ? null : '/preparation';
      }
      return {'/welcome', '/login', '/register'}.contains(path)
          ? null
          : '/welcome';
    },
    routes: [
      GoRoute(
        path: '/statistics',
        builder: (_, __) => const StatisticsScreen(),
      ),
      GoRoute(path: '/', redirect: (_, __) => '/splash'),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/mock-exams',
        builder: (_, __) => const MockHistoryScreen(),
      ),
      GoRoute(
        path: '/mock-exams/new',
        builder: (_, __) => const MockFormScreen(),
      ),
      GoRoute(
        path: '/mock-exams/:id/edit',
        builder: (_, s) => MockFormScreen(id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/mock-exams/:id',
        builder: (_, s) => MockDetailScreen(s.pathParameters['id']!),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/preparation',
        builder: (_, __) => const PreparationLoadingScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const GoalScreen()),
      GoRoute(
        path: '/goal/edit',
        builder: (_, __) => const GoalScreen(edit: true),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
