import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/domain/entities/zone.dart';
import 'package:namma_turfy/domain/entities/slot.dart';
import 'package:namma_turfy/domain/entities/coupon.dart';

abstract class VenueRepository {
  // Venues
  Stream<List<Venue>> watchAllVenues();
  Future<List<Venue>> searchVenues({String? sport, String? location});
  Future<Venue?> getVenueById(String id);
  Future<Venue?> getVenueByOwner(String ownerId);
  Future<void> saveVenue(Venue venue);

  // Zones
  Stream<List<Zone>> watchZones(String venueId);
  Future<void> saveZone(Zone zone);

  // Slots
  Stream<List<Slot>> watchSlots(String zoneId, {DateTime? date});
  Future<void> saveSlot(Slot slot);
  Future<void> bulkSaveSlots(List<Slot> slots);
  Future<void> deleteSlot(String slotId);

  // Coupons
  Stream<List<Coupon>> watchCoupons(String ownerId);
  Future<Coupon?> getCouponByCode(String code);
  Future<void> saveCoupon(Coupon coupon);
  Future<void> deleteCoupon(String couponId);
}
