import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/slot.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String playerId,
    required String venueId,
    required String zoneId,
    required List<Slot> slots,
    required double totalPrice,
    PaymentMethod paymentMethod,
  });
  Future<bool> lockSlots(List<Slot> slots);
  Stream<List<Booking>> watchPlayerBookings(String playerId);
  Stream<List<Booking>> watchVenueBookings(String venueId);
  Future<Booking?> getBookingById(String id);
}
