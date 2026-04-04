import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/booking.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.playerId,
    required super.venueId,
    required super.zoneId,
    required super.slotIds,
    required super.date,
    required super.createdAt,
    required super.totalPrice,
    super.discountedPrice,
    super.paymentMethod,
    required super.status,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      playerId: json['playerId'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      zoneId: json['zoneId'] as String? ?? '',
      slotIds: (json['slotIds'] as List?)?.cast<String>() ?? [],
      date: _parseDateTime(json['date']),
      createdAt: _parseDateTime(json['createdAt']),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discountedPrice'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'] == 'payAtVenue'
          ? PaymentMethod.payAtVenue
          : PaymentMethod.digital,
      status: _statusFromString(json['status'] as String? ?? 'confirmed'),
    );
  }

  factory BookingModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    // Convert Firestore Timestamps
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp)
          .toDate()
          .toIso8601String();
    }
    return BookingModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerId': playerId,
    'venueId': venueId,
    'zoneId': zoneId,
    'slotIds': slotIds,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'totalPrice': totalPrice,
    if (discountedPrice != null) 'discountedPrice': discountedPrice,
    'paymentMethod': paymentMethod == PaymentMethod.payAtVenue
        ? 'payAtVenue'
        : 'digital',
    'status': status.name,
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static BookingStatus _statusFromString(String s) {
    switch (s) {
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'pending':
        return BookingStatus.pending;
      default:
        return BookingStatus.confirmed;
    }
  }
}
