import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/data/models/booking_model.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<Booking> createBooking({
    required String playerId,
    required String venueId,
    required String zoneId,
    required List<Slot> slots,
    required double totalPrice,
    PaymentMethod paymentMethod = PaymentMethod.digital,
  }) async {
    try {
      final docRef = _firestore.collection('bookings').doc();

      final booking = BookingModel(
        id: docRef.id,
        playerId: playerId,
        venueId: venueId,
        zoneId: zoneId,
        slotIds: slots.map((s) => s.id).toList(),
        date: slots.first.startTime,
        createdAt: DateTime.now(),
        totalPrice: totalPrice,
        status: BookingStatus.confirmed,
        paymentMethod: paymentMethod,
      );

      final batch = _firestore.batch();
      batch.set(docRef, booking.toJson());

      for (final slot in slots) {
        final slotRef = _firestore.collection('slots').doc(slot.id);
        batch.update(slotRef, {
          'status': SlotStatus.booked.name,
          'holdExpiry': null,
        });
      }

      await batch.commit();
      print('Booking created successfully: ${booking.id}');
      return booking;
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  @override
  Future<bool> lockSlots(List<Slot> slots) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final slotDocs = <DocumentSnapshot>[];
        for (final slot in slots) {
          final ref = _firestore.collection('slots').doc(slot.id);
          final doc = await transaction.get(ref);
          if (!doc.exists) throw Exception('Slot does not exist: ${slot.id}');
          slotDocs.add(doc);
        }

        for (final doc in slotDocs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] != 'available') {
            throw Exception('One or more slots are no longer available.');
          }
        }

        final expiry = DateTime.now().add(const Duration(minutes: 5));
        for (final slot in slots) {
          final ref = _firestore.collection('slots').doc(slot.id);
          transaction.update(ref, {
            'status': SlotStatus.locked.name,
            'holdExpiry': expiry.toIso8601String(),
          });
        }
      });
      return true;
    } catch (e) {
      print('Error locking slots: $e');
      return false;
    }
  }

  @override
  Stream<List<Booking>> watchPlayerBookings(String playerId) {
    print('Watching bookings for player: $playerId');
    return _firestore
        .collection('bookings')
        .where('playerId', isEqualTo: playerId)
        .snapshots()
        .map(
      (snapshot) {
        print('Received ${snapshot.docs.length} bookings for player $playerId');
        return snapshot.docs
            .map((doc) => BookingModel.fromSnapshot(doc))
            .toList();
      },
    );
  }

  @override
  Stream<List<Booking>> watchVenueBookings(String venueId) {
    return _firestore
        .collection('bookings')
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromSnapshot(doc))
              .toList(),
        );
  }

  @override
  Future<Booking?> getBookingById(String id) async {
    final doc = await _firestore.collection('bookings').doc(id).get();
    if (!doc.exists) return null;
    return BookingModel.fromSnapshot(doc);
  }
}
