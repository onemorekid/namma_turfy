import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/slot.dart';

abstract class BookingRepository {
  /// Lock slots for [userId] for 10 minutes. Returns false if any slot
  /// is already locked/booked by someone else.
  Future<bool> lockSlots(List<Slot> slots, String userId);

  /// Verify that [userId] still holds locks on all [slots] and none have expired.
  Future<bool> verifyLocks(List<Slot> slots, String userId);

  Stream<List<Booking>> watchPlayerBookings(String playerId);
  Stream<List<Booking>> watchVenueBookings(String venueId);
  Future<Booking?> getBookingById(String id);
}
