import * as functions from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import axios from "axios";

/**
 * settleOwnerPayouts — runs every Monday at 9:00 AM IST (3:30 AM UTC).
 *
 * For each venue with pending unsettled bookings:
 *   1. Sums ownerPayout across all pending bookings
 *   2. Calls Razorpay Payout API to transfer to owner's fund account
 *   3. Marks bookings as settlementStatus = 'settled'
 *   4. Writes a settlement_records document (status: 'success')
 *
 * On payout failure:
 *   - Writes a settlement_failures document for ops visibility
 *   - Bookings remain in 'pending' state and will be retried next Monday
 */
export const settleOwnerPayouts = functions.onSchedule(
  {
    schedule: "30 3 * * 1", // Every Monday 3:30 AM UTC = 9:00 AM IST
    timeZone: "UTC",
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_PAYOUT_ACCOUNT"],
  },
  async () => {
    const db = admin.firestore();

    // ── 1. Fetch all unsettled confirmed bookings ─────────────────────────
    const bookingsSnap = await db
      .collection("bookings")
      .where("status", "==", "confirmed")
      .where("settlementStatus", "==", "pending")
      .get();

    if (bookingsSnap.empty) {
      console.log("No pending bookings to settle.");
      return;
    }

    // ── 2. Group by venueId ───────────────────────────────────────────────
    type BookingData = {
      id: string;
      venueId: string;
      ownerPayout: number;
      razorpayPaymentId?: string;
    };

    const byVenue = new Map<string, BookingData[]>();
    for (const doc of bookingsSnap.docs) {
      const data = doc.data() as BookingData;
      data.id = doc.id;
      const existing = byVenue.get(data.venueId) ?? [];
      existing.push(data);
      byVenue.set(data.venueId, existing);
    }

    // ── 3. Process each venue ─────────────────────────────────────────────
    for (const [venueId, bookings] of byVenue.entries()) {
      const venueSnap = await db.collection("venues").doc(venueId).get();
      if (!venueSnap.exists) {
        console.warn(`Venue ${venueId} not found, skipping.`);
        continue;
      }

      const venue = venueSnap.data()!;
      const fundAccountId = venue.razorpayFundAccountId as string | undefined;

      if (!fundAccountId) {
        console.warn(
          `Venue ${venueId} (${venue.name}) missing razorpayFundAccountId. Skipping.`
        );
        // Log as a settlement failure so ops can follow up
        await db.collection("settlement_failures").add({
          venueId,
          venueName: venue.name ?? "",
          ownerId: venue.ownerId ?? "",
          bookingCount: bookings.length,
          totalOwnerPayout: bookings.reduce((s, b) => s + (b.ownerPayout ?? 0), 0),
          bookingIds: bookings.map((b) => b.id),
          reason: "Missing razorpayFundAccountId — owner onboarding incomplete",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          retryable: true,
        });
        continue;
      }

      const totalOwnerPayout = bookings.reduce(
        (sum, b) => sum + (b.ownerPayout ?? 0),
        0
      );
      const amountInPaise = Math.round(totalOwnerPayout * 100);

      if (amountInPaise < 100) {
        console.log(`Skipping venue ${venueId}: payout < ₹1`);
        continue;
      }

      // ── 4. Call Razorpay Payout API ───────────────────────────────────────
      const referenceId = `settle_${venueId}_${Date.now()}`;
      let razorpayPayoutId: string | null = null;

      try {
        const payoutResponse = await axios.post(
          "https://api.razorpay.com/v1/payouts",
          {
            account_number: process.env.RAZORPAY_PAYOUT_ACCOUNT!,
            fund_account_id: fundAccountId,
            amount: amountInPaise,
            currency: "INR",
            mode: "IMPS",
            purpose: "vendor_advance",
            queue_if_low_balance: true,
            reference_id: referenceId,
            narration: `NammaTurfy settlement - ${venue.name}`,
          },
          {
            auth: {
              username: process.env.RAZORPAY_KEY_ID!,
              password: process.env.RAZORPAY_KEY_SECRET!,
            },
          }
        );

        razorpayPayoutId = payoutResponse.data.id as string;
        console.log(
          `Payout ${razorpayPayoutId} created for venue ${venueId}: ₹${totalOwnerPayout}`
        );

        // ── 5. Mark bookings as settled + write settlement record ───────────
        const batch = db.batch();
        for (const booking of bookings) {
          batch.update(db.collection("bookings").doc(booking.id), {
            settlementStatus: "settled",
          });
        }

        const totalCommission =
          bookingsSnap.docs
            .filter((d) => bookings.some((b) => b.id === d.id))
            .reduce((s, d) => s + ((d.data().platformCommission as number) ?? 0), 0);

        const settlementRef = db.collection("settlement_records").doc();
        batch.set(settlementRef, {
          venueId,
          venueName: venue.name ?? "",
          ownerId: venue.ownerId ?? "",
          bookingCount: bookings.length,
          totalOwnerPayout,
          totalCommission: parseFloat(totalCommission.toFixed(2)),
          amountInPaise,
          razorpayPayoutId,
          fundAccountId,
          referenceId,
          status: "success",
          settledAt: admin.firestore.FieldValue.serverTimestamp(),
          bookingIds: bookings.map((b) => b.id),
        });

        await batch.commit();
        console.log(
          `Settlement complete for venue ${venueId}: ${bookings.length} bookings, ₹${totalOwnerPayout}`
        );
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Payout failed for venue ${venueId}: ${msg}`);

        // Persist failure so ops team is alerted and can retry manually
        await db.collection("settlement_failures").add({
          venueId,
          venueName: venue.name ?? "",
          ownerId: venue.ownerId ?? "",
          bookingCount: bookings.length,
          totalOwnerPayout,
          amountInPaise,
          bookingIds: bookings.map((b) => b.id),
          referenceId,
          razorpayPayoutId, // null if Razorpay call failed outright
          reason: msg,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          retryable: true,
        });
        // Don't rethrow — continue processing other venues
      }
    }
  }
);
