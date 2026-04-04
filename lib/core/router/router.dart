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
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final user = authState.value;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (user.isSuspended) {
        return state.matchedLocation == '/suspended' ? null : '/suspended';
      }

      if (user.phoneNumber == null) {
        return state.matchedLocation == '/profile-completion'
            ? null
            : '/profile-completion';
      }

      if (isLoggingIn || isSplash || state.matchedLocation == '/profile-completion' || state.matchedLocation == '/suspended') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/suspended', builder: (context, state) => const SuspendedScreen()),
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
}
