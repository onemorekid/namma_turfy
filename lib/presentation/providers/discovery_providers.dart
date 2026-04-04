import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
