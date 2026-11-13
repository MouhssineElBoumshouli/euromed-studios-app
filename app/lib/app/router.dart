import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/backend.dart';
import '../features/booking/booking_flow_screen.dart';
import '../features/booking/sent_screen.dart';
import '../features/bookings/booking_detail_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/bookings/qr_pass_screen.dart';
import '../features/charter/charter_screen.dart';
import '../features/home/home_screen.dart';
import '../features/placeholder/coming_soon_screen.dart';
import '../features/planning/planning_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/regie/regie_screen.dart';
import '../features/regie/scanner_screen.dart';
import '../features/studios/studio_detail_screen.dart';
import '../features/studios/studios_screen.dart';
import '../features/validations/decision_screen.dart';
import '../features/validations/validations_screen.dart';
import 'login_screen.dart';
import 'shell.dart';

/// All the app's screens and their addresses.
///
/// Screen IDs in comments match docs/blueprint.md and the Figma frames.
/// Detail screens open on this navigator so they cover the tab bar.
final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  // Live demo: nobody gets past the sign-in screen without an account.
  refreshListenable: liveStatus,
  redirect: (context, state) {
    if (!isLive) return null;
    final atLogin = state.matchedLocation == '/login';
    if (liveStatus.value != LiveStatus.ready) {
      // Remember where the person was going, to land there after sign-in.
      return atLogin
          ? null
          : '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    if (!atLogin) return null;
    final from = state.uri.queryParameters['from'];
    return from != null && from.startsWith('/') && !from.startsWith('/login')
        ? from
        : '/home';
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        // B1
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        // C1, C2
        GoRoute(
          path: '/studios',
          builder: (_, __) => const StudiosScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootKey,
              builder: (_, st) =>
                  WideFrame(child: StudioDetailScreen(studioId: st.pathParameters['id']!)),
            ),
          ],
        ),
        // E1, E2
        GoRoute(
          path: '/bookings',
          builder: (_, __) => const BookingsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootKey,
              builder: (_, st) =>
                  WideFrame(child: BookingDetailScreen(bookingId: st.pathParameters['id']!)),
            ),
          ],
        ),
        // F1 (milestone 4)
        GoRoute(
          path: '/projects',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Projets',
            milestone: 'Étape 4',
            what: 'Le suivi de vos projets, du script à la livraison.',
          ),
        ),
        // G1 (milestone 3)
        GoRoute(
          path: '/validations',
          builder: (_, __) => const ValidationsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootKey,
              builder: (_, st) =>
                  WideFrame(child: DecisionScreen(bookingId: st.pathParameters['id']!)),
            ),
          ],
        ),
        // I2 (milestone 6)
        GoRoute(
          path: '/planning',
          builder: (_, __) => const PlanningScreen(),
        ),
        // H1 (milestone 5)
        GoRoute(
          path: '/regie',
          builder: (_, __) => const RegieScreen(),
        ),
        GoRoute(
          path: '/scanner',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const WideFrame(child: ScannerScreen()),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Maintenance',
            milestone: 'Étape 5',
            what: 'Les signalements de matériel, par gravité.',
          ),
        ),
        // I1 (milestone 6)
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Pilotage',
            milestone: 'Étape 6',
            what: 'Occupation, demandes en attente et incidents ouverts.',
          ),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Gestion',
            milestone: 'Étape 6',
            what:
                'Utilisateurs, salles, matériel et toutes les règles réglables.',
          ),
        ),
        // J1
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    // Full-screen flows, without the tab bar.
    // D1–D3
    GoRoute(
      path: '/book/:studioId',
      builder: (_, st) => WideFrame(child: BookingFlowScreen(
        studioId: st.pathParameters['studioId']!,
        initialDay: DateTime.tryParse(st.uri.queryParameters['day'] ?? ''),
      )),
    ),
    // D4
    GoRoute(
      path: '/sent/:id',
      builder: (_, st) => WideFrame(child: SentScreen(bookingId: st.pathParameters['id']!)),
    ),
    // E3
    GoRoute(
      path: '/qr/:id',
      builder: (_, st) => WideFrame(child: QrPassScreen(bookingId: st.pathParameters['id']!)),
    ),
    // A6
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/charter',
      builder: (_, __) => const WideFrame(child: CharterScreen()),
    ),
  ],
);
