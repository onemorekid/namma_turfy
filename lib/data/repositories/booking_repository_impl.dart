import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:namma_turfy/data/models/booking_model.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lock slots for this user for 10 minutes.
  /// A slot can only be locked if it is currently `available`.
  @override
  Future<bool> lockSlots(List<Slot> slots, String userId) async {
    debugPrint(
      '[lockSlots] Started for user $userId, slots: ${slots.map((s) => s.id)}',
    );
    try {
      await _firestore.runTransaction((tx) async {
        final refs = slots
            .map((s) => _firestore.collection('slots').doc(s.id))
            .toList();

        debugPrint('[lockSlots] Fetching ${refs.length} slot docs');
        // Read all in one batch first (required before writes in transaction)
        final docs = await Future.wait(refs.map((r) => tx.get(r)));

        final now = DateTime.now();
        for (final doc in docs) {
          if (!doc.exists) {
            debugPrint('[lockSlots] Slot ${doc.id} not found');
            throw Exception('Slot not found: ${doc.id}');
          }
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'available';
          if (status != 'available') {
            debugPrint('[lockSlots] Slot ${doc.id} is $status, not available');
            throw Exception('Slot ${doc.id} is no longer available');
          }

          final startTimeRaw = data['startTime'];
          if (startTimeRaw != null) {
            final startTime = startTimeRaw is Timestamp
                ? startTimeRaw.toDate()
                : DateTime.parse(startTimeRaw as String);
            if (startTime.isBefore(now)) {
              debugPrint('[lockSlots] Slot ${doc.id} is in the past');
              throw Exception('Slot ${doc.id} has already passed');
            }
          }
        }

        final expiry = DateTime.now().add(const Duration(minutes: 10));
        debugPrint('[lockSlots] Updating slots to locked status');
        for (final ref in refs) {
          tx.update(ref, {
            'status': SlotStatus.locked.name,
            'lockedBy': userId,
            'holdExpiry': Timestamp.fromDate(expiry),
          });
        }
      });
      debugPrint('[lockSlots] Transaction committed successfully');
      return true;
    } catch (e) {
      debugPrint('[lockSlots] Transaction failed: $e');
      return false;
    }
  }

  /// Verify that [userId] still holds active (non-expired) locks on all slots.
  @override
  Future<bool> verifyLocks(List<Slot> slots, String userId) async {
    debugPrint(
      '[BookingRepositoryImpl] verifyLocks: checking ${slots.length} slots for user $userId',
    );
    try {
      final now = DateTime.now();
      for (final slot in slots) {
        final doc = await _firestore.collection('slots').doc(slot.id).get();
        if (!doc.exists) {
          debugPrint(
            '[BookingRepositoryImpl] verifyLocks: slot ${slot.id} document missing',
          );
          return false;
        }
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] != 'locked') {
          debugPrint(
            '[BookingRepositoryImpl] verifyLocks: slot ${slot.id} is ${data['status']}, not locked',
          );
          return false;
        }
        if (data['lockedBy'] != userId) {
          debugPrint(
            '[BookingRepositoryImpl] verifyLocks: slot ${slot.id} locked by ${data['lockedBy']}, not $userId',
          );
          return false;
        }
        final expiryRaw = data['holdExpiry'];
        if (expiryRaw == null) {
          debugPrint(
            '[BookingRepositoryImpl] verifyLocks: slot ${slot.id} holdExpiry is null',
          );
          return false;
        }
        final expiry = expiryRaw is Timestamp
            ? expiryRaw.toDate()
            : DateTime.parse(expiryRaw as String);
        if (expiry.isBefore(now)) {
          debugPrint(
            '[BookingRepositoryImpl] verifyLocks: slot ${slot.id} hold expired at $expiry',
          );
          return false;
        }
      }
      debugPrint('[BookingRepositoryImpl] verifyLocks: all slots valid');
      return true;
    } catch (e) {
      debugPrint('[BookingRepositoryImpl] verifyLocks error: $e');
      return false;
    }
  }

  @override
  Stream<List<Booking>> watchPlayerBookings(String playerId) {
    return _firestore
        .collection('bookings')
        .where('playerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromSnapshot(d)).toList());
  }

  @override
  Stream<List<Booking>> watchVenueBookings(String venueId) {
    return _firestore
        .collection('bookings')
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromSnapshot(d)).toList());
  }

  @override
  Future<Booking?> getBookingById(String id) async {
    final doc = await _firestore.collection('bookings').doc(id).get();
    if (!doc.exists) return null;
    return BookingModel.fromSnapshot(doc);
  }
}
