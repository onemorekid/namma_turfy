import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/data/repositories/event_repository_impl.dart';
import 'package:namma_turfy/domain/entities/sport_event.dart';
import 'package:namma_turfy/domain/repositories/event_repository.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepositoryImpl();
});

final eventsProvider = FutureProvider<List<SportEvent>>((ref) {
  return ref.watch(eventRepositoryProvider).getEvents();
});

class EventController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> createEvent(SportEvent event) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).createEvent(event),
    );
    ref.invalidate(eventsProvider);
  }

  Future<void> joinEvent(String eventId, String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).joinEvent(eventId, userId),
    );
    ref.invalidate(eventsProvider);
  }
}

final eventControllerProvider =
    NotifierProvider<EventController, AsyncValue<void>>(EventController.new);
