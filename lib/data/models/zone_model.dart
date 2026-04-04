import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/zone.dart';

class ZoneModel extends Zone {
  const ZoneModel({
    required super.id,
    required super.venueId,
    required super.name,
    required super.type,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String,
      venueId: json['venueId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Cricket',
    );
  }

  factory ZoneModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    return ZoneModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'venueId': venueId,
    'name': name,
    'type': type,
  };
}
