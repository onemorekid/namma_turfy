import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:namma_turfy/data/models/venue_model.dart';
import 'package:namma_turfy/data/models/zone_model.dart';
import 'package:namma_turfy/data/models/slot_model.dart';
import 'package:namma_turfy/data/models/coupon_model.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/repositories/venue_repository.dart';

class VenueRepositoryImpl implements VenueRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<Venue>> watchAllVenues() {
    return _firestore.collection('venues').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => VenueModel.fromSnapshot(doc)).toList();
    });
  }

  @override
  Future<List<Venue>> searchVenues({String? sport, String? location}) async {
    Query query = _firestore.collection('venues');

    if (sport != null && sport.isNotEmpty) {
      query = query.where('sportsTypes', arrayContains: sport);
    }

    if (location != null && location.isNotEmpty) {
      // Very basic substring search simulation for Firestore
      query = query
          .where('location', isGreaterThanOrEqualTo: location)
          .where('location', isLessThanOrEqualTo: '$location\uf8ff');
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => VenueModel.fromSnapshot(doc)).toList();
  }

  @override
  Future<Venue?> getVenueById(String id) async {
    final doc = await _firestore.collection('venues').doc(id).get();
    if (!doc.exists) return null;
    return VenueModel.fromSnapshot(doc);
  }

  @override
  Future<Venue?> getVenueByOwner(String ownerId) async {
    final snapshot = await _firestore
        .collection('venues')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return VenueModel.fromSnapshot(snapshot.docs.first);
  }

  @override
  Future<void> saveVenue(Venue venue) async {
    final model = VenueModel(
      id: venue.id,
      ownerId: venue.ownerId,
      name: venue.name,
      location: venue.location,
      latitude: venue.latitude,
      longitude: venue.longitude,
      type: venue.type,
      rating: venue.rating,
      description: venue.description,
      pricePerHour: venue.pricePerHour,
      images: venue.images,
      features: venue.features,
      sportsTypes: venue.sportsTypes,
      availableHours: venue.availableHours,
      isSuspended: venue.isSuspended,
      commissionRate: venue.commissionRate,
    );
    await _firestore
        .collection('venues')
        .doc(venue.id)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Stream<List<Zone>> watchZones(String venueId) {
    return _firestore
        .collection('zones')
        .where('venueId', isEqualTo: venueId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ZoneModel.fromSnapshot(doc)).toList(),
        );
  }

  @override
  Future<void> saveZone(Zone zone) async {
    print('Saving zone: ${zone.id} - ${zone.name}');
    final model = ZoneModel(
      id: zone.id,
      venueId: zone.venueId,
      name: zone.name,
      type: zone.type,
    );
    await _firestore
        .collection('zones')
        .doc(zone.id)
        .set(model.toJson(), SetOptions(merge: true));
    print('Zone saved successfully');
  }

  @override
  Stream<List<Slot>> watchSlots(String zoneId, {DateTime? date}) {
    print('Watching slots for zone: $zoneId, date: $date');
    Query query = _firestore.collection('slots').where('zoneId', isEqualTo: zoneId);

    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      print('Filter range: $startOfDay to $endOfDay');
      query = query
          .where('startTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('startTime', isLessThanOrEqualTo: endOfDay.toIso8601String());
    }

    return query.snapshots().map(
          (snapshot) {
            print('Received ${snapshot.docs.length} slots from Firestore');
            return snapshot.docs.map((doc) => SlotModel.fromSnapshot(doc)).toList();
          },
        );
  }

  @override
  Future<void> saveSlot(Slot slot) async {
    print('Saving slot: ${slot.id} for zone: ${slot.zoneId} at ${slot.startTime}');
    final model = SlotModel(
      id: slot.id,
      zoneId: slot.zoneId,
      startTime: slot.startTime,
      endTime: slot.endTime,
      price: slot.price,
      status: slot.status,
      holdExpiry: slot.holdExpiry,
    );
    await _firestore
        .collection('slots')
        .doc(slot.id)
        .set(model.toJson(), SetOptions(merge: true));
    print('Slot saved successfully');
  }

  @override
  Future<void> bulkSaveSlots(List<Slot> slots) async {
    final batch = _firestore.batch();
    for (final slot in slots) {
      final model = SlotModel(
        id: slot.id,
        zoneId: slot.zoneId,
        startTime: slot.startTime,
        endTime: slot.endTime,
        price: slot.price,
        status: slot.status,
        holdExpiry: slot.holdExpiry,
      );
      final docRef = _firestore.collection('slots').doc(slot.id);
      batch.set(docRef, model.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Stream<List<Coupon>> watchCoupons(String ownerId) {
    return _firestore
        .collection('coupons')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CouponModel.fromSnapshot(doc))
              .toList(),
        );
  }

  @override
  Future<Coupon?> getCouponByCode(String code) async {
    final snapshot = await _firestore
        .collection('coupons')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return CouponModel.fromSnapshot(snapshot.docs.first);
  }

  @override
  Future<void> saveCoupon(Coupon coupon) async {
    final model = CouponModel(
      id: coupon.id,
      ownerId: coupon.ownerId,
      code: coupon.code,
      discountType: coupon.discountType,
      discountValue: coupon.discountValue,
      validTo: coupon.validTo,
      usageLimit: coupon.usageLimit,
      restrictedEmails: coupon.restrictedEmails,
    );
    await _firestore
        .collection('coupons')
        .doc(coupon.id)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteCoupon(String couponId) async {
    await _firestore.collection('coupons').doc(couponId).delete();
  }

  @override
  Future<void> deleteSlot(String slotId) async {
    await _firestore.collection('slots').doc(slotId).delete();
  }
}
