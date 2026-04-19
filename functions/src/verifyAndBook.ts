import * as functions from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import axios from "axios";

const DEFAULT_COMMISSION_RATE = 0.05;

/**
 * verifyAndBook — called by Flutter after Razorpay payment success.
 *
 * Security guarantees:
 *   1. Auth check — caller must be the authenticated player
 *   2. HMAC signature verification — proves Razorpay issued the payment
 *   3. Idempotency — duplicate calls with same paymentId return existing bookingId
 *   4. Slot lock check — slots must still be locked by this player (atomic)
 *   5. Coupon usage limit — atomically enforced inside the Firestore transaction
 *   6. razorpaySignature stored — cryptographic audit trail
 *   7. Auto-refund — if the transaction fails after payment, money is returned
 *
 * Input: {
 *   razorpayOrderId, razorpayPaymentId, razorpaySignature,
 *   playerId, venueId, zoneId, slotIds, couponCode?
 * }
 * Output: { bookingId }
 */
export const verifyAndBook = functions.onCall(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"] },
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

    if (request.auth.uid !== playerId) {
      throw new functions.HttpsError("permission-denied", "playerId mismatch");
    }

    console.log(`[verifyAndBook] Started for player ${playerId}, order ${razorpayOrderId}, payment ${razorpayPaymentId}`);

    // ── 1. Verify HMAC signature ──────────────────────────────────────────
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keySecret) {
      console.error("[verifyAndBook] RAZORPAY_KEY_SECRET missing");
      throw new functions.HttpsError(
        "failed-precondition",
        "Payment gateway is not configured"
      );
    }

    const expectedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    if (expectedSignature !== razorpaySignature) {
      console.error(`[verifyAndBook] Signature mismatch. Expected ${expectedSignature.substring(0, 8)}..., got ${razorpaySignature.substring(0, 8)}...`);
      throw new functions.HttpsError(
        "unauthenticated",
        "Payment signature verification failed"
      );
    }

    const db = admin.firestore();

    // ── 2. Idempotency: return existing booking if already processed ────────
    const existingBookings = await db
      .collection("bookings")
      .where("razorpayPaymentId", "==", razorpayPaymentId)
      .limit(1)
      .get();

    if (!existingBookings.empty) {
      console.log(
        `[verifyAndBook] Idempotency hit: payment ${razorpayPaymentId} already has booking ${existingBookings.docs[0].id}`
      );
      return { bookingId: existingBookings.docs[0].id };
    }

    // ── 3. Fetch slot docs + venue ─────────────────────────────────────────
    const slotRefs = slotIds.map((id) => db.collection("slots").doc(id));
    const [venueSnap, ...slotDocs] = await Promise.all([
      db.collection("venues").doc(venueId).get(),
      ...slotRefs.map((r) => r.get()),
    ]);

    const subtotal = slotDocs.reduce(
      (sum, doc) => sum + ((doc.data()?.price as number) ?? 0),
      0
    );

    const rawRate = venueSnap.data()?.commissionRate;
    const commissionRate =
      typeof rawRate === "number" && rawRate > 0
        ? rawRate / 100
        : DEFAULT_COMMISSION_RATE;

    // ── 4. Server-side coupon validation + fetch coupon ref for transaction ─
    let discount = 0;
    let couponRef: admin.firestore.DocumentReference | null = null;
    let couponDocId: string | null = null;

    if (couponCode) {
      const couponSnap = await db
        .collection("coupons")
        .where("code", "==", couponCode.toUpperCase())
        .limit(1)
        .get();

      if (!couponSnap.empty) {
        const couponDoc = couponSnap.docs[0];
        const couponData = couponDoc.data();

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
            emailAllowed = restrictedEmails.includes(userRecord.email ?? "");
          }

          if (emailAllowed) {
            const discountType: string = couponData.discountType ?? "percentage";
            const discountValue: number = couponData.discountValue ?? 0;
            discount =
              discountType === "percentage"
                ? subtotal * (discountValue / 100)
                : discountValue;

            couponRef = couponDoc.ref;
            couponDocId = couponDoc.id;
          }
        }
      }
    }

    const charged = Math.max(0, subtotal - discount);
    const platformCommission = parseFloat((charged * commissionRate).toFixed(2));
    const ownerPayout = parseFloat((charged - platformCommission).toFixed(2));
    const bookingRef = db.collection("bookings").doc();

    // ── 5. Atomic transaction ──────────────────────────────────────────────
    try {
      await db.runTransaction(async (tx) => {
        const txSlotDocs = await Promise.all(slotRefs.map((r) => tx.get(r)));

        // 5a. Verify slot locks
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

        // 5b. Coupon usage limit check + atomic increment
        if (couponRef && couponDocId) {
          const couponTx = await tx.get(couponRef);
          const usageCount: number = couponTx.data()?.usageCount ?? 0;
          const usageLimit: number = couponTx.data()?.usageLimit ?? 100;
          if (usageCount >= usageLimit) {
            throw new functions.HttpsError(
              "resource-exhausted",
              "This coupon has reached its usage limit"
            );
          }
          tx.update(couponRef, {
            usageCount: admin.firestore.FieldValue.increment(1),
          });

          // Audit record for this coupon use
          const usageLogRef = db.collection("coupon_usages").doc();
          tx.set(usageLogRef, {
            couponId: couponDocId,
            couponCode: couponCode!.toUpperCase(),
            playerId,
            bookingId: bookingRef.id,
            discountApplied: discount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // 5c. Mark slots as booked
        for (const ref of slotRefs) {
          tx.update(ref, { status: "booked", lockedBy: null, holdExpiry: null });
        }

        // 5d. Create booking (razorpaySignature stored for cryptographic audit)
        const venueData = venueSnap.data();
        const bookingData: Record<string, unknown> = {
          id: bookingRef.id,
          playerId,
          venueId,
          zoneId,
          slotIds,
          venueName: venueData?.name ?? null,
          venueLocation: venueData?.location ?? null,
          date: txSlotDocs[0].data()!.startTime,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          totalPrice: subtotal,
          platformCommission,
          ownerPayout,
          razorpayOrderId,
          razorpayPaymentId,
          razorpaySignature,
          paymentMethod: "digital",
          status: "confirmed",
          settlementStatus: "pending",
          paymentVerifiedBy: "client_sdk",
        };

        if (discount > 0) {
          bookingData.discountedPrice = charged;
          bookingData.couponCode = couponCode!.toUpperCase();
        }

        tx.set(bookingRef, bookingData);

        // 5e. Mark pending_orders as processed
        tx.update(db.collection("pending_orders").doc(razorpayOrderId), {
          status: "processed",
          bookingId: bookingRef.id,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (txError) {
      const errMessage =
        txError instanceof functions.HttpsError
          ? txError.message
          : String(txError);

      console.error(
        `[verifyAndBook] Transaction failed for payment ${razorpayPaymentId}: ${errMessage}`
      );

      // Signature was already verified → money was taken. Auto-refund.
      const isBookingLogicError =
        txError instanceof functions.HttpsError &&
        ["failed-precondition", "not-found", "resource-exhausted"].includes(
          txError.code
        );

      if (isBookingLogicError) {
        await _attemptRefund(razorpayPaymentId, errMessage, playerId, slotIds, db);
      }

      throw txError;
    }

    console.log(
      `[verifyAndBook] Booking ${bookingRef.id} created for payment ${razorpayPaymentId}`
    );
    return { bookingId: bookingRef.id };
  }
);

// ── Shared helper: attempt Razorpay refund + log to orphaned_payments ─────────

export async function _attemptRefund(
  razorpayPaymentId: string,
  reason: string,
  playerId: string,
  slotIds: string[],
  db: admin.firestore.Firestore
): Promise<void> {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  const orphanedRef = db.collection("orphaned_payments").doc(razorpayPaymentId);

  if (!keyId || !keySecret) {
    console.error("[verifyAndBook] Cannot refund — Razorpay keys missing");
    await orphanedRef.set({
      razorpayPaymentId,
      playerId,
      slotIds,
      reason,
      refundStatus: "keys_missing",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  try {
    const refundResponse = await axios.post(
      `https://api.razorpay.com/v1/payments/${razorpayPaymentId}/refund`,
      { speed: "normal" },
      { auth: { username: keyId, password: keySecret } }
    );
    const refundId = refundResponse.data?.id as string;
    console.log(
      `[verifyAndBook] Auto-refund ${refundId} issued for payment ${razorpayPaymentId}`
    );
    await orphanedRef.set({
      razorpayPaymentId,
      playerId,
      slotIds,
      reason,
      refundStatus: "refunded",
      razorpayRefundId: refundId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (refundErr) {
    const refundErrMsg =
      refundErr instanceof Error ? refundErr.message : String(refundErr);
    console.error(
      `[verifyAndBook] Auto-refund FAILED for payment ${razorpayPaymentId}: ${refundErrMsg}`
    );
    await orphanedRef.set({
      razorpayPaymentId,
      playerId,
      slotIds,
      reason,
      refundStatus: "refund_failed",
      refundError: refundErrMsg,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}
