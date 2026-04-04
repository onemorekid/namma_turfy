import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/data/models/sport_event_model.dart';
import 'package:namma_turfy/domain/entities/sport_event.dart';
import 'package:namma_turfy/domain/repositories/event_repository.dart';

class EventRepositoryImpl implements EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<SportEvent>> getEvents() async {
    final query = await _firestore.collection('events').orderBy('date').get();
    return query.docs.map((doc) => SportEventModel.fromSnapshot(doc)).toList();
  }

  @override
  Future<void> createEvent(SportEvent event) async {
    final model = SportEventModel(
      id: event.id,
      title: event.title,
      description: event.description,
      venueId: event.venueId,
      date: event.date,
      time: event.time,
      organizerId: event.organizerId,
      participants: event.participants,
      sport: event.sport,
      type: event.type,
    );
    await _firestore.collection('events').doc(event.id).set(model.toJson());
  }

  @override
  Future<void> joinEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }
}
