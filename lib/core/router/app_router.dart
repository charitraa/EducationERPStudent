import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/fees/fees_screen.dart';
import '../../features/notices/notices_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/results/report_card_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/more_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/timetable/timetable_screen.dart';

const _publicPaths = {'/login', '/forgot-password'};

/// Where an auth state sends a request for [path], or null to allow it.
/// Signed-out users can only reach the login screens; nothing behind the
/// shell renders without a session.
String? authRedirect(AuthStatus status, String path) {
  final isPublic = _publicPaths.contains(path);
  switch (status) {
    case AuthStatus.unknown:
    case AuthStatus.offline:
      return path == '/splash' ? null : '/splash';
    case AuthStatus.signedOut:
      return isPublic ? null : '/login';
    case AuthStatus.signedIn:
      return (isPublic || path == '/splash') ? '/' : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthStatus>(AuthStatus.unknown);
  ref.listen(authControllerProvider.select((s) => s.status), (_, next) => refresh.value = next, fireImmediately: true);
  ref.onDispose(refresh.dispose);

  int? idParam(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '');
  Widget notFound() => const _NotFound();

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(authControllerProvider).status, state.matchedLocation),
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, _) => const NoTransitionPage(child: DashboardScreen())),
          GoRoute(path: '/timetable', pageBuilder: (_, _) => const NoTransitionPage(child: TimetableScreen())),
          GoRoute(path: '/attendance', pageBuilder: (_, _) => const NoTransitionPage(child: AttendanceScreen())),
          GoRoute(
            path: '/results',
            pageBuilder: (_, s) => NoTransitionPage(
              child: ResultsScreen(initialTab: s.uri.queryParameters['tab'] == 'exams' ? 1 : 0),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => idParam(s) == null ? notFound() : ReportCardScreen(resultId: idParam(s)!),
              ),
            ],
          ),
          GoRoute(path: '/more', pageBuilder: (_, _) => const NoTransitionPage(child: MoreScreen())),
          GoRoute(
            path: '/notices',
            builder: (_, _) => const NoticesScreen(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => idParam(s) == null ? notFound() : NoticeDetailScreen(id: idParam(s)!)),
            ],
          ),
          GoRoute(path: '/fees', builder: (_, _) => const FeesScreen()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/support',
            builder: (_, _) => const SupportScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewTicketScreen()),
              GoRoute(path: ':id', builder: (_, s) => idParam(s) == null ? notFound() : TicketDetailScreen(id: idParam(s)!)),
            ],
          ),
        ],
      ),
    ],
  );
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This page doesn\'t exist.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/'), child: const Text('Go home')),
        ]),
      ),
    );
  }
}
