class CouponUsage {
  final String id;
  final String couponId;
  final String couponCode;
  final String playerId;
  final String bookingId;
  final double discountApplied;
  final DateTime createdAt;

  const CouponUsage({
    required this.id,
    required this.couponId,
    required this.couponCode,
    required this.playerId,
    required this.bookingId,
    required this.discountApplied,
    required this.createdAt,
  });
}
