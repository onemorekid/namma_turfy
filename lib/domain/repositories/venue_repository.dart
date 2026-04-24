import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';
import 'package:namma_turfy/domain/entities/coupon_usage.dart';

abstract class VenueRepository {
  // Venues
  Stream<List<Venue>> watchAllVenues({String? city});
  Stream<Venue?> watchVenueById(String id);
  Future<List<Venue>> searchVenues({String? sport, String? location});
  Future<Venue?> getVenueById(String id);
  Future<Venue?> getVenueByOwner(String ownerId);
  Stream<List<Venue>> watchVenuesByOwner(String ownerId);
  Future<void> saveVenue(Venue venue);

  // Zones
  Stream<List<Zone>> watchZones(String venueId);
  Future<void> saveZone(Zone zone);

  // Slots
  Stream<List<Slot>> watchSlots(String zoneId, {DateTime? date});
  Future<List<Slot>> getSlotsInRange(
    String zoneId,
    DateTime start,
    DateTime end,
  );
  Future<void> saveSlot(Slot slot);
  Future<void> bulkSaveSlots(List<Slot> slots);
  Future<void> deleteSlot(String slotId);
  Future<void> recalculateAvailableHours(String venueId);

  // Coupons
  Stream<List<Coupon>> watchCoupons(String ownerId);
  Future<Coupon?> getCouponByCode(String code);
  Future<void> saveCoupon(Coupon coupon);
  Future<void> deleteCoupon(String couponId);
  Stream<List<CouponUsage>> watchCouponUsages(String couponId, String ownerId);
}
