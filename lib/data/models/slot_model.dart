import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/slot.dart';

class SlotModel extends Slot {
  const SlotModel({
    required super.id,
    required super.zoneId,
    required super.startTime,
    super.endTime,
    required super.price,
    required super.status,
    super.holdExpiry,
    super.lockedBy,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String,
      zoneId: json['zoneId'] as String? ?? '',
      startTime: _parseDateTime(json['startTime']),
      endTime: json['endTime'] != null ? _parseDateTime(json['endTime']) : null,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: _statusFromString(json['status'] as String? ?? 'available'),
      holdExpiry: json['holdExpiry'] != null
          ? _parseDateTime(json['holdExpiry'])
          : null,
      lockedBy: json['lockedBy'] as String?,
    );
  }

  factory SlotModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    _convertTimestamp(data, 'startTime');
    _convertTimestamp(data, 'endTime');
    _convertTimestamp(data, 'holdExpiry');
    return SlotModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'zoneId': zoneId,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'price': price,
    'status': status.name,
    if (holdExpiry != null) 'holdExpiry': holdExpiry!.toIso8601String(),
    if (lockedBy != null) 'lockedBy': lockedBy,
  };

  static void _convertTimestamp(Map<String, dynamic> data, String key) {
    if (data[key] is Timestamp) {
      data[key] = (data[key] as Timestamp).toDate().toIso8601String();
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static SlotStatus _statusFromString(String s) {
    switch (s) {
      case 'locked':
        return SlotStatus.locked;
      case 'booked':
        return SlotStatus.booked;
      default:
        return SlotStatus.available;
    }
  }
}
