enum DiscountType { percentage, flat }

class Coupon {
  final String id;
  final String ownerId;
  final String code;
  final DiscountType discountType;
  final double discountValue;
  final DateTime validTo;
  final int usageLimit;
  final int usageCount;
  final List<String>? restrictedEmails;

  const Coupon({
    required this.id,
    required this.ownerId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.validTo,
    this.usageLimit = 100,
    this.usageCount = 0,
    this.restrictedEmails,
  });
}
