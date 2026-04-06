import * as functions from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Razorpay from "razorpay";

/**
 * createOrder — called by Flutter before opening Razorpay SDK.
 *
 * Input  (body): { amountInPaise: number, venueId: string, playerId: string, couponCode?: string }
 * Output (json): { orderId, amount, currency, keyId, discountApplied }
 *
 * Set secrets via:
 *   firebase functions:secrets:set RAZORPAY_KEY_ID
 *   firebase functions:secrets:set RAZORPAY_KEY_SECRET
 */
export const createOrder = functions.onCall(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"] },
  async (request) => {
    console.log("[createOrder] Function started");
    // ── 0. Auth check ─────────────────────────────────────────────────────
    if (!request.auth) {
      console.warn("[createOrder] Unauthenticated request");
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

    console.log(`[createOrder] slotIds: ${slotIds}, venueId: ${venueId}, playerId: ${playerId}, couponCode: ${couponCode}`);

    if (!slotIds || slotIds.length === 0) {
      console.warn("[createOrder] slotIds are required but missing or empty");
      throw new functions.HttpsError(
        "invalid-argument",
        "slotIds are required"
      );
    }
    if (!venueId || !playerId) {
      console.warn(`[createOrder] Missing venueId or playerId: venueId=${venueId}, playerId=${playerId}`);
      throw new functions.HttpsError(
        "invalid-argument",
        "venueId and playerId are required"
      );
    }

    // ── 0.1 Player ID check ────────────────────────────────────────────────
    if (request.auth.uid !== playerId) {
      console.warn(`[createOrder] auth.uid mismatch: auth.uid=${request.auth.uid}, playerId=${playerId}`);
      throw new functions.HttpsError(
        "permission-denied",
        "playerId does not match authenticated user"
      );
    }

    const db = admin.firestore();

    // ── 0.2 Fetch slot docs to compute server-side subtotal ─────────────────
    const slotRefs = slotIds.map((id) => db.collection("slots").doc(id));
    const slotDocs = await Promise.all(slotRefs.map((r) => r.get()));

    let subtotalInPaise = 0;
    for (const doc of slotDocs) {
      if (!doc.exists) {
        console.error(`[createOrder] Slot doc ${doc.id} not found`);
        throw new functions.HttpsError("not-found", `Slot ${doc.id} not found`);
      }
      const data = doc.data();
      const price = (data?.price as number) ?? 0;
      subtotalInPaise += Math.round(price * 100);
      console.log(`[createOrder] Slot ${doc.id} price: ${price}, subtotal: ${subtotalInPaise}`);
    }

    if (subtotalInPaise < 100) {
      console.warn(`[createOrder] subtotalInPaise (${subtotalInPaise}) is too low`);
      throw new functions.HttpsError(
        "failed-precondition",
        "Total amount must be at least ₹1"
      );
    }

    // ── 1. Coupon validation (before creating Razorpay order) ──────────────
    let discountedAmountInPaise = subtotalInPaise;
    let couponDiscount = 0;

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
          // Check restricted emails if present
          const restrictedEmails: string[] | undefined = couponData.restrictedEmails;
          let emailAllowed = true;
          if (restrictedEmails && restrictedEmails.length > 0) {
            const userRecord = await admin.auth().getUser(request.auth.uid);
            const userEmail = userRecord.email ?? "";
            emailAllowed = restrictedEmails.includes(userEmail);
          }

          if (emailAllowed) {
            const discountType: string = couponData.discountType ?? "percentage";
            const discountValue: number = couponData.discountValue ?? 0;

            if (discountType === "percentage") {
              couponDiscount = Math.round(subtotalInPaise * (discountValue / 100));
            } else {
              // flat discount — value is in rupees, convert to paise
              couponDiscount = Math.round(discountValue * 100);
            }

            discountedAmountInPaise = Math.max(100, subtotalInPaise - couponDiscount);
            couponDiscount = subtotalInPaise - discountedAmountInPaise;
          }
        }
      }
    }

    // ── 2. Create Razorpay order ───────────────────────────────────────────
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      console.error("[createOrder] Razorpay API keys are missing in secrets");
      throw new functions.HttpsError(
        "failed-precondition",
        "Payment gateway is not configured (missing API keys)"
      );
    }

    console.log(`[createOrder] Creating Razorpay order with amount: ${discountedAmountInPaise}`);
    const razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });

    try {
      const order = await razorpay.orders.create({
        amount: discountedAmountInPaise,
        currency: "INR",
        receipt: `rcpt_${playerId.substring(0, Math.min(8, playerId.length))}_${Date.now()}`,
        notes: { venueId, playerId },
      });

      console.log(`[createOrder] Razorpay order created: ${order.id}`);

      // Explicitly convert amount to a plain JS number (not RazorpayAmount / Int64)
      // so the Dart cloud_functions package doesn't wrap it in fixnum.Int64,
      // which the Razorpay Flutter SDK cannot consume.
      return {
        orderId: String(order.id),
        amount: Number(order.amount),
        currency: String(order.currency),
        keyId: keyId,
        discountApplied: Number(couponDiscount),
      };
    } catch (e) {
      console.error("[createOrder] Razorpay order creation failed:", e);
      throw new functions.HttpsError("internal", "Could not create payment order via Razorpay");
    }
  }
);
