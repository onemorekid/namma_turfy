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
    required super.startTime,
    required super.endTime,
    required super.createdAt,
    required super.totalPrice,
    super.discountedPrice,
    required super.platformCommission,
    required super.ownerPayout,
    super.venueName,
    super.venueLocation,
    super.zoneName,
    super.sportType,
    super.playerName,
    super.playerPhone,
    super.couponCode,
    super.razorpayOrderId,
    super.razorpayPaymentId,
    super.razorpaySignature,
    super.paymentMethod,
    required super.status,
    super.settlementStatus,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final charged =
        (json['discountedPrice'] as num?)?.toDouble() ??
        (json['totalPrice'] as num?)?.toDouble() ??
        0.0;
    final date = _parseDateTime(json['date']);
    return BookingModel(
      id: json['id'] as String,
      playerId: json['playerId'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      zoneId: json['zoneId'] as String? ?? '',
      slotIds: (json['slotIds'] as List?)?.cast<String>() ?? [],
      date: date,
      startTime: json['startTime'] != null
          ? _parseDateTime(json['startTime'])
          : date,
      endTime: json['endTime'] != null
          ? _parseDateTime(json['endTime'])
          : date.add(const Duration(hours: 1)),
      createdAt: _parseDateTime(json['createdAt']),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discountedPrice'] as num?)?.toDouble(),
      platformCommission:
          (json['platformCommission'] as num?)?.toDouble() ?? charged * 0.05,
      ownerPayout: (json['ownerPayout'] as num?)?.toDouble() ?? charged * 0.95,
      venueName: json['venueName'] as String?,
      venueLocation: json['venueLocation'] as String?,
      zoneName: json['zoneName'] as String?,
      sportType: json['sportType'] as String?,
      playerName: json['playerName'] as String?,
      playerPhone: json['playerPhone'] as String?,
      couponCode: json['couponCode'] as String?,
      razorpayOrderId: json['razorpayOrderId'] as String?,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      razorpaySignature: json['razorpaySignature'] as String?,
      paymentMethod: PaymentMethod.digital,
      status: _statusFromString(json['status'] as String? ?? 'confirmed'),
      settlementStatus: json['settlementStatus'] == 'settled'
          ? SettlementStatus.settled
          : SettlementStatus.pending,
    );
  }

  factory BookingModel.fromSnapshot(DocumentSnapshot snap) {
    final data = Map<String, dynamic>.from(snap.data() as Map<String, dynamic>? ?? {});
    data['id'] = snap.id;
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    if (data['startTime'] is Timestamp) {
      data['startTime'] = (data['startTime'] as Timestamp)
          .toDate()
          .toIso8601String();
    }
    if (data['endTime'] is Timestamp) {
      data['endTime'] = (data['endTime'] as Timestamp)
          .toDate()
          .toIso8601String();
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
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'totalPrice': totalPrice,
    if (discountedPrice != null) 'discountedPrice': discountedPrice,
    'platformCommission': platformCommission,
    'ownerPayout': ownerPayout,
    if (venueName != null) 'venueName': venueName,
    if (venueLocation != null) 'venueLocation': venueLocation,
    if (zoneName != null) 'zoneName': zoneName,
    if (sportType != null) 'sportType': sportType,
    if (playerName != null) 'playerName': playerName,
    if (playerPhone != null) 'playerPhone': playerPhone,
    if (couponCode != null) 'couponCode': couponCode,
    if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
    if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
    if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
    'paymentMethod': 'digital',
    'status': status.name,
    'settlementStatus': settlementStatus.name,
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
