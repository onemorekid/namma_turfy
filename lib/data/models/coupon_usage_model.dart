import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/coupon_usage.dart';

class CouponUsageModel extends CouponUsage {
  const CouponUsageModel({
    required super.id,
    required super.couponId,
    required super.couponCode,
    required super.playerId,
    required super.bookingId,
    required super.discountApplied,
    required super.createdAt,
  });

  factory CouponUsageModel.fromJson(Map<String, dynamic> json) {
    return CouponUsageModel(
      id: json['id'] as String,
      couponId: json['couponId'] as String,
      couponCode: json['couponCode'] as String,
      playerId: json['playerId'] as String,
      bookingId: json['bookingId'] as String,
      discountApplied: (json['discountApplied'] as num).toDouble(),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  factory CouponUsageModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>;
    data['id'] = snap.id;
    return CouponUsageModel.fromJson(data);
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
