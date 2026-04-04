import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/data/repositories/venue_repository_impl.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/repositories/venue_repository.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

// Import the existing detail providers to reuse or stay consistent
import 'package:namma_turfy/presentation/providers/venue_detail_providers.dart';

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return VenueRepositoryImpl();
});

final allVenuesProvider = StreamProvider<List<Venue>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(venueRepositoryProvider).watchAllVenues();
});

final venuesProvider = allVenuesProvider;

final venueProvider = FutureProvider.family<Venue?, String>((ref, id) {
  return ref.watch(venueRepositoryProvider).getVenueById(id);
});

final venueZonesProvider =
    StreamProvider.family<List<Zone>, String>((ref, venueId) {
      return ref.watch(venueRepositoryProvider).watchZones(venueId);
    });

// Use a distinct date provider for the owner dashboard to avoid side effects with the player view
final ownerSelectedDateProvider =
    NotifierProvider<OwnerSelectedDateNotifier, DateTime>(
      OwnerSelectedDateNotifier.new,
    );

class OwnerSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  set value(DateTime val) => state = val;
}

final zoneSlotsProvider =
    StreamProvider.family<List<Slot>, String>((ref, zoneId) {
      // Logic: if we are in owner mode, we might want to watch ownerSelectedDateProvider
      // but the detail screen uses selectedDateProvider.
      // We can use a simple trick: check which one is "active" or just use a parameter if possible.
      // Since StreamProvider.family only takes one arg, we use the provider that's relevant.
      
      // Let's check if we can detect the context. Actually, better to have a dedicated provider for Owner slots
      // or just accept that this provider watches a specific date provider.
      
      final date = ref.watch(ownerSelectedDateProvider);
      return ref.watch(venueRepositoryProvider).watchSlots(zoneId, date: date);
    });

// Dedicated provider for player view to avoid confusion
final playerZoneSlotsProvider =
    StreamProvider.family<List<Slot>, String>((ref, zoneId) {
      final date = ref.watch(selectedDateProvider);
      return ref.watch(venueRepositoryProvider).watchSlots(zoneId, date: date);
    });

final ownerVenueProvider = FutureProvider<Venue?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);
  return ref.watch(venueRepositoryProvider).getVenueByOwner(user.id);
});

final ownerCouponsProvider = StreamProvider<List<Coupon>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(venueRepositoryProvider).watchCoupons(user.id);
});

final venueSearchControllerProvider =
    AsyncNotifierProvider<VenueSearchController, List<Venue>>(
      VenueSearchController.new,
    );

class VenueSearchController extends AsyncNotifier<List<Venue>> {
  @override
  Future<List<Venue>> build() async {
    return [];
  }

  Future<void> search({String? sport, String? location}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final venues = await ref
          .read(venueRepositoryProvider)
          .searchVenues(sport: sport, location: location);
      return venues;
    });
  }
}

final adminControllerProvider = AsyncNotifierProvider<AdminController, void>(
  AdminController.new,
);

class AdminController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  Future<void> updateCommissionRate(String venueId, int rate) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(venueRepositoryProvider);
      final venue = await repo.getVenueById(venueId);
      if (venue != null) {
        await repo.saveVenue(venue.copyWith(commissionRate: rate));
      }
    });
  }
}
