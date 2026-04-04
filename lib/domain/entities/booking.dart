enum BookingStatus { pending, confirmed, cancelled }

enum PaymentMethod { digital, payAtVenue }

class Booking {
  final String id;
  final String playerId;
  final String venueId;
  final String zoneId;
  final List<String> slotIds;
  final DateTime date;
  final DateTime createdAt;
  final double totalPrice;
  final double? discountedPrice;
  final PaymentMethod paymentMethod;
  final BookingStatus status;

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
    this.paymentMethod = PaymentMethod.digital,
    required this.status,
  });
}
