import 'package:namma_turfy/domain/entities/sport_event.dart';

abstract class EventRepository {
  Future<List<SportEvent>> getEvents();
  Future<void> createEvent(SportEvent event);
  Future<void> joinEvent(String eventId, String userId);
}
