import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/sport_event.dart';

class SportEventModel extends SportEvent {
  const SportEventModel({
    required super.id,
    required super.title,
    required super.description,
    required super.venueId,
    required super.date,
    required super.time,
    required super.organizerId,
    required super.participants,
    required super.sport,
    required super.type,
  });

  factory SportEventModel.fromJson(Map<String, dynamic> json) {
    return SportEventModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      organizerId: json['organizerId'] as String? ?? '',
      participants: (json['participants'] as List?)?.cast<String>() ?? [],
      sport: json['sport'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  factory SportEventModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    return SportEventModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'venueId': venueId,
    'date': date,
    'time': time,
    'organizerId': organizerId,
    'participants': participants,
    'sport': sport,
    'type': type,
  };
}
