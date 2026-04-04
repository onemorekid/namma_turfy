import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/data/repositories/booking_repository_impl.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/repositories/booking_repository.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl();
});

final playerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(bookingRepositoryProvider).watchPlayerBookings(user.id);
});

final venueBookingsStreamProvider =
    StreamProvider.family<List<Booking>, String>((ref, venueId) {
      return ref.watch(bookingRepositoryProvider).watchVenueBookings(venueId);
    });

final bookingByIdProvider = FutureProvider.family<Booking?, String>((ref, id) {
  return ref.watch(bookingRepositoryProvider).getBookingById(id);
});
