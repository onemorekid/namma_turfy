import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:namma_turfy/domain/entities/zone.dart';

class ZoneModel extends Zone {
  const ZoneModel({
    required super.id,
    required super.venueId,
    required super.name,
    required super.type,
    super.images,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    final List<String> images = [];
    if (json['images'] is List) {
      images.addAll((json['images'] as List).cast<String>());
    }
    if (json['imageUrls'] is List) {
      for (final url in (json['imageUrls'] as List).cast<String>()) {
        if (!images.contains(url)) images.add(url);
      }
    }

    if (images.isEmpty) {
      debugPrint('[ZoneModel] WARNING: No images found for zone ${json['id']}');
    } else {
      debugPrint('[ZoneModel] Found ${images.length} images for zone ${json['id']}');
    }

    return ZoneModel(
      id: json['id'] as String,
      venueId: json['venueId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Cricket',
      images: images,
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
    'images': images,
  };
}
