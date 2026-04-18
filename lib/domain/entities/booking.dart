enum BookingStatus { pending, confirmed, cancelled }

// payAtVenue removed — digital only
enum PaymentMethod { digital }

enum SettlementStatus { pending, settled }

class Booking {
  final String id;
  final String playerId;
  final String venueId;
  final String zoneId;
  final List<String> slotIds;
  final DateTime date;
  final DateTime createdAt;

  // Pricing
  final double totalPrice; // amount player paid
  final double? discountedPrice; // after coupon (what razorpay charged)
  final double platformCommission; // 5% of discountedPrice
  final double ownerPayout; // discountedPrice - platformCommission

  // Denormalized venue info (set at booking time for fast list rendering)
  final String? venueName;
  final String? venueLocation;

  // Razorpay audit trail
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature; // HMAC stored for cryptographic verification

  final PaymentMethod paymentMethod;
  final BookingStatus status;
  final SettlementStatus settlementStatus;

  const Booking({
    required this.id,
    required this.playerId,
    required this.venueId,
    required this.zoneId,
    required this.slotIds,
    required this.date,
    required this.createdAt,
    required this.totalPrice,
    this.discountedPrice,
    required this.platformCommission,
    required this.ownerPayout,
    this.venueName,
    this.venueLocation,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.paymentMethod = PaymentMethod.digital,
    required this.status,
    this.settlementStatus = SettlementStatus.pending,
  });

  // Convenience: actual amount charged to player
  double get amountCharged => discountedPrice ?? totalPrice;
}
