import * as functions from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Commission rate is read per-venue from Firestore (set by admin).
// Default fallback is 5% if somehow unset.
const DEFAULT_COMMISSION_RATE = 0.05;

/**
 * verifyAndBook — called by Flutter after Razorpay payment success.
 *
 * Verifies HMAC signature, then atomically:
 *   1. Confirms all slots are still locked by this player
 *   2. Marks slots as `booked`
 *   3. Creates the booking document with commission split
 *
 * Input: {
 *   razorpayOrderId, razorpayPaymentId, razorpaySignature,
 *   playerId, venueId, zoneId, slotIds,
 *   totalPrice, couponCode?
 * }
 * Output: { bookingId }
 */
export const verifyAndBook = functions.onCall(
  { secrets: ["RAZORPAY_KEY_SECRET"] },
  async (request) => {
    // ── 0. Auth check ─────────────────────────────────────────────────────
    if (!request.auth) {
      throw new functions.HttpsError(
        "unauthenticated",
        "You must be signed in to complete a booking"
      );
    }

    const {
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
      playerId,
      venueId,
      zoneId,
      slotIds,
      couponCode,
    } = request.data as {
      razorpayOrderId: string;
      razorpayPaymentId: string;
      razorpaySignature: string;
      playerId: string;
      venueId: string;
      zoneId: string;
      slotIds: string[];
      couponCode?: string;
    };

    // ── 1. Player ID check ────────────────────────────────────────────────
    if (request.auth.uid !== playerId) {
      throw new functions.HttpsError(
        "permission-denied",
        "playerId mismatch"
      );
    }

    // ── 2. Verify HMAC signature ──────────────────────────────────────────
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keySecret) {
      console.error("[verifyAndBook] RAZORPAY_KEY_SECRET is missing");
      throw new functions.HttpsError("failed-precondition", "Payment gateway is not configured");
    }

    const body = `${razorpayOrderId}|${razorpayPaymentId}`;
    const expectedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(body)
      .digest("hex");

    if (expectedSignature !== razorpaySignature) {
      throw new functions.HttpsError(
        "unauthenticated",
        "Payment signature verification failed"
      );
    }

    const db = admin.firestore();

    // ── 3. Fetch slot docs to compute server-side subtotal ─────────────────
    const slotRefs = slotIds.map((id) => db.collection("slots").doc(id));

    // Read the negotiated commission rate for this specific venue.
    const [venueSnap, ...slotDocs] = await Promise.all([
      db.collection("venues").doc(venueId).get(),
      ...slotRefs.map((r) => r.get()),
    ]);

    const subtotal = slotDocs.reduce((sum, doc) => {
      return sum + ((doc.data()?.price as number) ?? 0);
    }, 0);

    const rawRate = venueSnap.data()?.commissionRate;
    const commissionRate =
      typeof rawRate === "number" && rawRate > 0
        ? rawRate / 100
        : DEFAULT_COMMISSION_RATE;

    // ── 4. Server-side coupon validation ──────────────────────────────────
    let discount = 0;

    if (couponCode) {
      const couponSnap = await db
        .collection("coupons")
        .where("code", "==", couponCode.toUpperCase())
        .limit(1)
        .get();

      if (!couponSnap.empty) {
        const couponData = couponSnap.docs[0].data();
        const validTo: admin.firestore.Timestamp | string = couponData.validTo;
        const validToMs =
          validTo instanceof admin.firestore.Timestamp
            ? validTo.toMillis()
            : new Date(validTo as string).getTime();

        if (validToMs >= Date.now()) {
          const restrictedEmails: string[] | undefined = couponData.restrictedEmails;
          let emailAllowed = true;
          if (restrictedEmails && restrictedEmails.length > 0) {
            const userRecord = await admin.auth().getUser(playerId);
            const userEmail = userRecord.email ?? "";
            emailAllowed = restrictedEmails.includes(userEmail);
          }

          if (emailAllowed) {
            const discountType: string = couponData.discountType ?? "percentage";
            const discountValue: number = couponData.discountValue ?? 0;

            if (discountType === "percentage") {
              discount = subtotal * (discountValue / 100);
            } else {
              discount = discountValue;
            }
          }
        }
      }
    }

    const charged = Math.max(0, subtotal - discount);
    const platformCommission = parseFloat((charged * commissionRate).toFixed(2));
    const ownerPayout = parseFloat((charged - platformCommission).toFixed(2));

    // ── 5. Atomic transaction: verify locks → book slots → create booking ──
    const bookingRef = db.collection("bookings").doc();

    await db.runTransaction(async (tx) => {
      const txSlotDocs = await Promise.all(slotRefs.map((r) => tx.get(r)));

      // Verify every slot is still locked by this player and not expired
      const now = admin.firestore.Timestamp.now();
      for (const doc of txSlotDocs) {
        if (!doc.exists) {
          throw new functions.HttpsError("not-found", `Slot ${doc.id} not found`);
        }
        const data = doc.data()!;
        if (data.status !== "locked") {
          throw new functions.HttpsError(
            "failed-precondition",
            `Slot ${doc.id} is no longer locked`
          );
        }
        if (data.lockedBy !== playerId) {
          throw new functions.HttpsError(
            "failed-precondition",
            `Slot ${doc.id} is locked by another player`
          );
        }
        const expiry = data.holdExpiry as admin.firestore.Timestamp | string;
        const expiryMs =
          typeof expiry === "string"
            ? new Date(expiry).getTime()
            : (expiry as admin.firestore.Timestamp).toMillis();
        if (expiryMs < now.toMillis()) {
          throw new functions.HttpsError(
            "failed-precondition",
            "Slot hold has expired. Please select slots again."
          );
        }
      }

      // Mark all slots as booked
      for (const ref of slotRefs) {
        tx.update(ref, { status: "booked", lockedBy: null, holdExpiry: null });
      }

      // Create booking document
      const bookingData: Record<string, unknown> = {
        id: bookingRef.id,
        playerId,
        venueId,
        zoneId,
        slotIds,
        date: txSlotDocs[0].data()!.startTime,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        totalPrice: subtotal,
        platformCommission,
        ownerPayout,
        razorpayOrderId,
        razorpayPaymentId,
        paymentMethod: "digital",
        status: "confirmed",
        settlementStatus: "pending",
      };

      if (discount > 0) {
        bookingData.discountedPrice = charged;
      }

      tx.set(bookingRef, bookingData);
    });

    return { bookingId: bookingRef.id };
  }
);
