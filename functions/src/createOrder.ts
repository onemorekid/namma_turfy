import * as functions from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Razorpay from "razorpay";

/**
 * createOrder — called by Flutter before opening Razorpay SDK.
 *
 * 1. Validates auth + inputs
 * 2. Computes server-side subtotal from Firestore slot prices
 * 3. Validates coupon (expiry, email restriction, usage limit)
 * 4. Creates a Razorpay order
 * 5. Writes a `pending_orders/{razorpayOrderId}` document so the webhook
 *    can recover orphaned payments if the app crashes before verifyAndBook.
 *
 * Secrets required:
 *   firebase functions:secrets:set RAZORPAY_KEY_ID
 *   firebase functions:secrets:set RAZORPAY_KEY_SECRET
 */
export const createOrder = functions.onCall(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"] },
  async (request) => {
    // ── 0. Auth check ─────────────────────────────────────────────────────
    if (!request.auth) {
      throw new functions.HttpsError(
        "unauthenticated",
        "You must be signed in to create an order"
      );
    }

    const { slotIds, venueId, playerId, couponCode } = request.data as {
      slotIds: string[];
      venueId: string;
      playerId: string;
      couponCode?: string;
    };

    if (!slotIds || slotIds.length === 0) {
      throw new functions.HttpsError("invalid-argument", "slotIds are required");
    }
    if (!venueId || !playerId) {
      throw new functions.HttpsError(
        "invalid-argument",
        "venueId and playerId are required"
      );
    }
    if (request.auth.uid !== playerId) {
      throw new functions.HttpsError(
        "permission-denied",
        "playerId does not match authenticated user"
      );
    }

    const db = admin.firestore();

    // ── 1. Fetch slot docs → server-side subtotal ──────────────────────────
    const slotRefs = slotIds.map((id) => db.collection("slots").doc(id));
    const slotDocs = await Promise.all(slotRefs.map((r) => r.get()));

    let subtotalInPaise = 0;
    let zoneId = "";
    for (const doc of slotDocs) {
      if (!doc.exists) {
        throw new functions.HttpsError("not-found", `Slot ${doc.id} not found`);
      }
      const data = doc.data()!;
      subtotalInPaise += Math.round(((data.price as number) ?? 0) * 100);
      if (!zoneId) zoneId = (data.zoneId as string) ?? "";
    }

    if (subtotalInPaise < 100) {
      throw new functions.HttpsError(
        "failed-precondition",
        "Total amount must be at least ₹1"
      );
    }

    // ── 2. Coupon validation ───────────────────────────────────────────────
    let discountedAmountInPaise = subtotalInPaise;
    let couponDiscount = 0;
    let couponDocId: string | null = null;

    if (couponCode) {
      const couponSnap = await db
        .collection("coupons")
        .where("code", "==", couponCode.toUpperCase())
        .limit(1)
        .get();

      if (couponSnap.empty) {
        throw new functions.HttpsError("not-found", "Invalid coupon code");
      }

      const couponDoc = couponSnap.docs[0];
      const couponData = couponDoc.data();

      const validTo: admin.firestore.Timestamp | string = couponData.validTo;
      const validToMs =
        validTo instanceof admin.firestore.Timestamp
          ? validTo.toMillis()
          : new Date(validTo as string).getTime();

      if (validToMs < Date.now()) {
        throw new functions.HttpsError("failed-precondition", "Coupon has expired");
      }

      // Check usage limit (pre-check; atomic enforcement happens in verifyAndBook)
      const usageCount: number = couponData.usageCount ?? 0;
      const usageLimit: number = couponData.usageLimit ?? 100;
      if (usageCount >= usageLimit) {
        throw new functions.HttpsError(
          "resource-exhausted",
          "This coupon has reached its usage limit"
        );
      }

      // Check restricted emails
      const restrictedEmails: string[] | undefined = couponData.restrictedEmails;
      if (restrictedEmails && restrictedEmails.length > 0) {
        const userRecord = await admin.auth().getUser(request.auth.uid);
        if (!restrictedEmails.includes(userRecord.email ?? "")) {
          throw new functions.HttpsError(
            "permission-denied",
            "This coupon is not valid for your account"
          );
        }
      }

      const discountType: string = couponData.discountType ?? "percentage";
      const discountValue: number = couponData.discountValue ?? 0;

      if (discountType === "percentage") {
        couponDiscount = Math.round(subtotalInPaise * (discountValue / 100));
      } else {
        couponDiscount = Math.round(discountValue * 100);
      }

      discountedAmountInPaise = Math.max(100, subtotalInPaise - couponDiscount);
      couponDiscount = subtotalInPaise - discountedAmountInPaise;
      couponDocId = couponDoc.id;
    }

    // ── 3. Create Razorpay order ───────────────────────────────────────────
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret) {
      throw new functions.HttpsError(
        "failed-precondition",
        "Payment gateway is not configured"
      );
    }

    const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let order: any;
    try {
      order = await razorpay.orders.create({
        amount: discountedAmountInPaise,
        currency: "INR",
        receipt: `rcpt_${playerId.substring(0, 8)}_${Date.now()}`,
        notes: { venueId, playerId, zoneId },
      });
    } catch (e) {
      console.error("[createOrder] Razorpay order creation failed:", e);
      throw new functions.HttpsError(
        "internal",
        "Could not create payment order via Razorpay"
      );
    }
    if (!order || !order.id) {
      throw new functions.HttpsError("internal", "Razorpay returned an empty order");
    }

    // ── 4. Persist pending_orders for webhook recovery ─────────────────────
    // The Razorpay webhook uses this document to reconstruct the booking if
    // the app crashes after payment but before verifyAndBook is called.
    await db.collection("pending_orders").doc(String(order.id)).set({
      razorpayOrderId: String(order.id),
      slotIds,
      venueId,
      zoneId,
      playerId,
      couponCode: couponCode ?? null,
      couponDocId,
      amountInPaise: Number(order.amount),
      status: "pending", // updated to 'processed' by verifyAndBook / webhook
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[createOrder] Order ${order.id} created for player ${playerId}`);

    return {
      orderId: String(order.id),
      amount: Number(order.amount),
      currency: String(order.currency),
      keyId,
      discountApplied: Number(couponDiscount),
    };
  }
);
