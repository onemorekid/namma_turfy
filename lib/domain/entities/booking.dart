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
  final DateTime date; // legacy field — prefer startTime
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  // Pricing
  final double totalPrice; // amount player paid
  final double? discountedPrice; // after coupon (what razorpay charged)
  final double platformCommission; // 5% of discountedPrice
  final double ownerPayout; // discountedPrice - platformCommission

  // Denormalized venue/player info (set at booking time for fast list rendering)
  final String? venueName;
  final String? venueLocation;
  final String? zoneName;
  final String? sportType;
  final String? playerName;
  final String? playerPhone;
  final String? couponCode;

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
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.totalPrice,
    this.discountedPrice,
    required this.platformCommission,
    required this.ownerPayout,
    this.venueName,
    this.venueLocation,
    this.zoneName,
    this.sportType,
    this.playerName,
    this.playerPhone,
    this.couponCode,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.paymentMethod = PaymentMethod.digital,
    required this.status,
    this.settlementStatus = SettlementStatus.pending,
  });

  // Convenience: actual amount charged to player
  double get amountCharged => discountedPrice ?? totalPrice;

  String get displayStatus {
    if (status == BookingStatus.cancelled) return 'Cancelled';
    if (status == BookingStatus.pending) return 'Pending';

    final now = DateTime.now();
    if (now.isBefore(startTime)) return 'Upcoming';
    if (now.isAfter(endTime)) return 'Completed';
    return 'Ongoing';
  }
}
