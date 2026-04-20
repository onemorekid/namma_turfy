import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/data/repositories/venue_repository_impl.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/coupon_usage.dart';
import 'package:namma_turfy/domain/repositories/venue_repository.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return VenueRepositoryImpl();
});

final allVenuesProvider = StreamProvider<List<Venue>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref
      .watch(venueRepositoryProvider)
      .watchAllVenues(city: user?.preferredCity);
});

final venuesProvider = allVenuesProvider;

final venueProvider = FutureProvider.family<Venue?, String>((ref, id) {
  return ref.watch(venueRepositoryProvider).getVenueById(id);
});

final venueZonesProvider = StreamProvider.family<List<Zone>, String>((
  ref,
  venueId,
) {
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

/// A single slot stream provider parameterised by both zoneId and date.
/// Usage: ref.watch(zoneSlotsFamily((zoneId: id, date: selectedDate)))
final zoneSlotsFamily =
    StreamProvider.family<List<Slot>, ({String zoneId, DateTime date})>((
      ref,
      params,
    ) {
      return ref
          .watch(venueRepositoryProvider)
          .watchSlots(params.zoneId, date: params.date);
    });

/// ownerVenuesProvider — streams all venues owned by the current user.
final ownerVenuesProvider = StreamProvider<List<Venue>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(venueRepositoryProvider).watchVenuesByOwner(user.id);
});

/// ownerVenueProvider — backward-compat alias that returns the first venue.
final ownerVenueProvider = FutureProvider<Venue?>((ref) async {
  final venues = await ref.watch(ownerVenuesProvider.future);
  return venues.isEmpty ? null : venues.first;
});

final ownerCouponsProvider = StreamProvider<List<Coupon>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(venueRepositoryProvider).watchCoupons(user.id);
});

/// Streams coupon usage records for a specific coupon owned by a given owner.
/// Both couponId and ownerId are required for Firestore rule compliance.
final couponUsagesProvider = StreamProvider.family<
  List<CouponUsage>,
  ({String couponId, String ownerId})
>((ref, params) {
  return ref
      .watch(venueRepositoryProvider)
      .watchCouponUsages(params.couponId, params.ownerId);
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
      await FirebaseFirestore.instance.collection('venues').doc(venueId).update(
        {'commissionRate': rate},
      );
    });
  }
}
