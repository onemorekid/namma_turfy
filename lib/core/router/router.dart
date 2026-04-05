import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/screens/admin_dashboard_screen.dart';
import 'package:namma_turfy/presentation/screens/checkout_screen.dart';
import 'package:namma_turfy/presentation/screens/event_discovery_screen.dart';
import 'package:namma_turfy/presentation/screens/home_screen.dart';
import 'package:namma_turfy/presentation/screens/login_screen.dart';
import 'package:namma_turfy/presentation/screens/owner_dashboard_screen.dart';
import 'package:namma_turfy/presentation/screens/player_bookings_screen.dart';
import 'package:namma_turfy/presentation/screens/profile_completion_screen.dart';
import 'package:namma_turfy/presentation/screens/receipt_screen.dart';
import 'package:namma_turfy/presentation/screens/splash_screen.dart';
import 'package:namma_turfy/presentation/screens/suspended_screen.dart';
import 'package:namma_turfy/presentation/screens/venue_details_screen.dart';
import 'package:namma_turfy/presentation/screens/venue_list_screen.dart';

/// Listens to [authStateChangesProvider] and notifies GoRouter to
/// re-evaluate its redirect whenever the auth state changes.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    // Whenever auth state emits a new value, tell GoRouter to re-run redirect.
    _ref.listen<AsyncValue<dynamic>>(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateChangesProvider);

    // Still loading — don't redirect yet.
    if (authState.isLoading) return null;

    final user = authState.value;
    final loc = state.matchedLocation;

    // Not logged in → always go to login.
    if (user == null) {
      return loc == '/login' ? null : '/login';
    }

    // Suspended account.
    if (user.isSuspended) {
      return loc == '/suspended' ? null : '/suspended';
    }

    // Profile not complete (phone number missing).
    if (user.phoneNumber == null) {
      return loc == '/profile-completion' ? null : '/profile-completion';
    }

    // Logged-in user trying to access auth-only screens → send home.
    if (loc == '/login' ||
        loc == '/splash' ||
        loc == '/suspended' ||
        loc == '/profile-completion') {
      return '/';
    }

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspendedScreen(),
      ),
      GoRoute(
        path: '/profile-completion',
        builder: (context, state) => const ProfileCompletionScreen(),
      ),
      GoRoute(
        path: '/venues',
        builder: (context, state) => const VenueListScreen(),
      ),
      GoRoute(
        path: '/venue/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VenueDetailsScreen(venueId: id);
        },
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventDiscoveryScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CheckoutScreen(
            venue: extra['venue'] as Venue,
            slots: extra['slots'] as List<Slot>,
            lockedByUserId: extra['lockedByUserId'] as String,
          );
        },
      ),
      GoRoute(
        path: '/receipt/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReceiptScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/my-bookings',
        builder: (context, state) => const PlayerBookingsScreen(),
      ),
    ],
  );
});
