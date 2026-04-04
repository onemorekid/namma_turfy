import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/domain/entities/slot.dart';

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  set value(DateTime val) => state = val;
}

final selectedZoneIdProvider =
    NotifierProvider<SelectedZoneIdNotifier, String?>(
      SelectedZoneIdNotifier.new,
    );

class SelectedZoneIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  set value(String? val) => state = val;
}

final selectedSlotsProvider =
    NotifierProvider<SelectedSlotsNotifier, List<Slot>>(
      SelectedSlotsNotifier.new,
    );

class SelectedSlotsNotifier extends Notifier<List<Slot>> {
  @override
  List<Slot> build() => [];
  set value(List<Slot> val) => state = val;
}
