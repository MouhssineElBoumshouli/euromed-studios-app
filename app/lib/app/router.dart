import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/placeholder/coming_soon_screen.dart';
import '../features/profile/profile_screen.dart';
import 'shell.dart';

/// All the app's screens and their addresses.
///
/// Screen IDs in comments match docs/blueprint.md and the Figma frames.
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        // B1
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        // C1 (milestone 2)
        GoRoute(
          path: '/studios',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Studios',
            milestone: 'Étape 2',
            what:
                'La liste des studios par zone, avec filtres et disponibilité en direct.',
          ),
        ),
        // E1 (milestone 2)
        GoRoute(
          path: '/bookings',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Réservations',
            milestone: 'Étape 2',
            what: 'Vos demandes à venir, en attente, passées et refusées.',
          ),
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
          builder: (_, __) => const ComingSoonScreen(
            title: 'Validations',
            milestone: 'Étape 3',
            what: 'Les demandes qui attendent votre décision.',
          ),
        ),
        // I2 (milestone 6)
        GoRoute(
          path: '/planning',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Planning',
            milestone: 'Étape 5',
            what: 'Toutes les salles sur une même frise horaire.',
          ),
        ),
        // H1 (milestone 5)
        GoRoute(
          path: '/regie',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Régie',
            milestone: 'Étape 5',
            what: 'L’occupation des studios en direct.',
          ),
        ),
        GoRoute(
          path: '/scanner',
          builder: (_, __) => const ComingSoonScreen(
            title: 'Scanner',
            milestone: 'Étape 5',
            what: 'Scanner les QR codes d’accès à l’entrée.',
          ),
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
            title: 'Tableau de bord',
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
  ],
);
