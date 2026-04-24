import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:namma_turfy/core/utils/proximity_helper.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

final userPositionProvider = NotifierProvider<UserPositionNotifier, Position?>(
  UserPositionNotifier.new,
);

class UserPositionNotifier extends Notifier<Position?> {
  @override
  Position? build() => null;
  set value(Position? val) => state = val;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
      SelectedCategoryNotifier.new,
    );

class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';
  set value(String val) => state = val;
}

final selectedHourProvider = NotifierProvider<SelectedHourNotifier, int?>(
  SelectedHourNotifier.new,
);

class SelectedHourNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  set value(int? val) => state = val;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  set value(String val) => state = val;
}

final filteredVenuesProvider = Provider<AsyncValue<List<Venue>>>((ref) {
  final venuesAsync = ref.watch(allVenuesProvider);
  final userPos = ref.watch(userPositionProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedHour = ref.watch(selectedHourProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return venuesAsync.whenData((venues) {
    var filtered = venues.where((v) => !v.isSuspended).toList();

    if (selectedCategory != 'All') {
      filtered = filtered
          .where((v) => v.sportsTypes.contains(selectedCategory))
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (v) =>
                v.name.toLowerCase().contains(query) ||
                v.location.toLowerCase().contains(query),
          )
          .toList();
    }

    if (selectedHour != null) {
      filtered = filtered.where((v) {
        // Primary: check denormalized field (F-06)
        if (v.availableSlotHours.isNotEmpty) {
          return v.availableSlotHours.contains(selectedHour);
        }
        // Fallback: check legacy operating hours (until recalculated)
        if (v.availableHours.isNotEmpty) {
          final hours = v.availableHours
              .map((h) => int.tryParse(h.split(':').first))
              .whereType<int>()
              .toSet();
          return hours.contains(selectedHour);
        }
        return true; // No data = don't filter out yet
      }).toList();
    }

    if (userPos != null) {
      filtered.sort((a, b) {
        final dA = ProximityHelper.calculateDistance(
          userPos.latitude,
          userPos.longitude,
          a.latitude,
          a.longitude,
        );
        final dB = ProximityHelper.calculateDistance(
          userPos.latitude,
          userPos.longitude,
          b.latitude,
          b.longitude,
        );
        return dA.compareTo(dB);
      });
    }

    return filtered;
  });
});
