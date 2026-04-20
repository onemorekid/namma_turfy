import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';

class CouponModel extends Coupon {
  const CouponModel({
    required super.id,
    required super.ownerId,
    required super.code,
    required super.discountType,
    required super.discountValue,
    required super.validTo,
    super.usageLimit,
    super.usageCount,
    super.restrictedEmails,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      discountType: json['discountType'] == 'flat'
          ? DiscountType.flat
          : DiscountType.percentage,
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      validTo: _parseDateTime(json['validTo']),
      usageLimit: (json['usageLimit'] as num?)?.toInt() ?? 100,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      restrictedEmails: (json['restrictedEmails'] as List?)?.cast<String>(),
    );
  }

  factory CouponModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    if (data['validTo'] is Timestamp) {
      data['validTo'] = (data['validTo'] as Timestamp)
          .toDate()
          .toIso8601String();
    }
    return CouponModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'code': code,
    'discountType': discountType == DiscountType.flat ? 'flat' : 'percentage',
    'discountValue': discountValue,
    'validTo': validTo.toIso8601String(),
    'usageLimit': usageLimit,
    'usageCount': usageCount,
    if (restrictedEmails != null) 'restrictedEmails': restrictedEmails,
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
