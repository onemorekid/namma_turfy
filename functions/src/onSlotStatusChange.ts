import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Trigger: When any slot document in 'slots' collection is created or updated.
 * Logic: Recalculate available hours for the parent Venue and update 'availableSlotHours' field.
 * This ensures the home screen time filter is always accurate.
 */
export const onSlotStatusChange = functions.firestore
  .document("slots/{slotId}")
  .onWrite(async (change, context) => {
    const db = admin.firestore();
    
    // 1. Get zoneId from the slot document (from either before or after state)
    const data = change.after.exists ? change.after.data() : change.before.data();
    if (!data) return null;
    
    const zoneId = data.zoneId;
    if (!zoneId) return null;

    // 2. Find venueId by looking up the zone
    const zoneSnap = await db.collection("zones").doc(zoneId).get();
    if (!zoneSnap.exists) return null;
    
    const venueId = zoneSnap.data()?.venueId;
    if (!venueId) return null;

    // 3. Query ALL available slots for this venue across ALL its zones for TODAY
    // First, get all zoneIds for this venue
    const zonesSnap = await db.collection("zones").where("venueId", "==", venueId).get();
    const venueZoneIds = zonesSnap.docs.map(doc => doc.id);
    
    if (venueZoneIds.length === 0) return null;

    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.month, now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.month, now.getDate(), 23, 59, 59);

    // Fetch available slots for these zones
    // Note: Firestore 'in' query supports up to 30 items. 
    // Most venues have < 30 zones, so this is safe for MVP.
    const availableSlotsSnap = await db.collection("slots")
      .where("zoneId", "in", venueZoneIds)
      .where("status", "==", "available")
      .where("startTime", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
      .where("startTime", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
      .get();

    // 4. Extract unique hours (0-23)
    const availableHoursSet = new Set<number>();
    availableSlotsSnap.docs.forEach(doc => {
      const slotData = doc.data();
      const startTime = slotData.startTime.toDate();
      // Only include if it's in the future (optional, but better for filter)
      if (startTime > now) {
        availableHoursSet.add(startTime.getHours());
      }
    });

    const availableHoursList = Array.from(availableHoursSet).sort((a, b) => a - b);

    // 5. Update the Venue document
    await db.collection("venues").doc(venueId).update({
      availableSlotHours: availableHoursList,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Updated availableSlotHours for Venue ${venueId}: ${availableHoursList}`);
    return null;
  });
