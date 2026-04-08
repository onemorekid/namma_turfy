import * as functionsV2 from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { _attemptRefund } from "./verifyAndBook";

/**
 * razorpayWebhook — Razorpay server-to-server event handler.
 *
 * This is the safety net for the payment flow. If the Flutter app crashes
 * after payment but before verifyAndBook is called, Razorpay will retry
 * this webhook. The function:
 *
 *   1. Verifies the webhook signature (X-Razorpay-Signature header)
 *   2. On payment.captured:
 *      - Checks idempotency (skip if booking already exists)
 *      - Looks up pending_orders/{orderId} to get slotIds/playerId/etc.
 *      - Creates the booking atomically (same logic as verifyAndBook)
 *   3. On payment.failed:
 *      - Logs to payment_attempts for ops visibility
 *
 * Configure in Razorpay Dashboard → Webhooks → add your function URL.
 * Set the webhook secret via:
 *   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
 */
export const razorpayWebhook = functionsV2.onRequest(
  { secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET"] },
  async (req, res) => {
    // ── 1. Verify webhook signature ────────────────────────────────────────
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.error("[webhook] RAZORPAY_WEBHOOK_SECRET not set");
      res.status(500).send("Webhook secret not configured");
      return;
    }

    const signature = req.headers["x-razorpay-signature"] as string | undefined;
    if (!signature) {
      res.status(400).send("Missing X-Razorpay-Signature header");
      return;
    }

    // req.rawBody is set by Cloud Functions HTTP framework
    const rawBody: Buffer = (req as unknown as { rawBody: Buffer }).rawBody;
    if (!rawBody) {
      res.status(400).send("Missing raw body");
      return;
    }

    const expectedSig = crypto
      .createHmac("sha256", webhookSecret)
      .update(rawBody)
      .digest("hex");

    if (expectedSig !== signature) {
      console.warn("[webhook] Invalid webhook signature");
      res.status(400).send("Invalid signature");
      return;
    }

    // ── 2. Parse event ─────────────────────────────────────────────────────
    const event = req.body as {
      event: string;
      payload: {
        payment?: {
          entity: {
            id: string;
            order_id: string;
            amount: number;
            status: string;
            error_code?: string;
            error_description?: string;
          };
        };
      };
    };

    const db = admin.firestore();
    const paymentEntity = event.payload?.payment?.entity;

    if (!paymentEntity) {
      res.status(200).send("No payment entity — ignored");
      return;
    }

    const razorpayPaymentId = paymentEntity.id;
    const razorpayOrderId = paymentEntity.order_id;

    // ── 3. Handle payment.captured ─────────────────────────────────────────
    if (event.event === "payment.captured") {
      console.log(`[webhook] payment.captured: ${razorpayPaymentId} / order ${razorpayOrderId}`);

      // 3a. Idempotency: skip if booking already exists
      const existingBooking = await db
        .collection("bookings")
        .where("razorpayPaymentId", "==", razorpayPaymentId)
        .limit(1)
        .get();

      if (!existingBooking.empty) {
        console.log(`[webhook] Booking already exists for payment ${razorpayPaymentId}, skipping`);
        res.status(200).send("Already processed");
        return;
      }

      // 3b. Look up pending_orders to get booking context
      const pendingOrderSnap = await db
        .collection("pending_orders")
        .doc(razorpayOrderId)
        .get();

      if (!pendingOrderSnap.exists) {
        console.error(`[webhook] No pending_order found for order ${razorpayOrderId}`);
        // Log to orphaned_payments for manual intervention
        await db.collection("orphaned_payments").doc(razorpayPaymentId).set({
          razorpayPaymentId,
          razorpayOrderId,
          reason: "No pending_order document found",
          refundStatus: "manual_review_required",
          source: "webhook",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(200).send("Logged for manual review");
        return;
      }

      const po = pendingOrderSnap.data()!;
      // If already processed (verifyAndBook got there first), skip
      if (po.status === "processed") {
        console.log(`[webhook] pending_order ${razorpayOrderId} already processed`);
        res.status(200).send("Already processed");
        return;
      }

      const { slotIds, venueId, zoneId, playerId, couponCode, couponDocId } = po as {
        slotIds: string[];
        venueId: string;
        zoneId: string;
        playerId: string;
        couponCode?: string;
        couponDocId?: string;
      };

      // 3c. Fetch slot + venue data
      const slotRefs = slotIds.map((id: string) => db.collection("slots").doc(id));
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
        typeof rawRate === "number" && rawRate > 0 ? rawRate / 100 : 0.05;

      // 3d. Coupon discount (read-only here; usageCount already incremented if
      //     createOrder ran — we don't increment again in webhook path to avoid
      //     double-counting. The coupon_usages doc is also skipped here.)
      let discount = 0;
      let couponRefForTx: admin.firestore.DocumentReference | null = null;
      if (couponCode && couponDocId) {
        const couponSnap = await db.collection("coupons").doc(couponDocId).get();
        if (couponSnap.exists) {
          const cd = couponSnap.data()!;
          const discountType: string = cd.discountType ?? "percentage";
          const discountValue: number = cd.discountValue ?? 0;
          discount =
            discountType === "percentage"
              ? subtotal * (discountValue / 100)
              : discountValue;
          couponRefForTx = couponSnap.ref;
        }
      }

      const charged = Math.max(0, subtotal - discount);
      const platformCommission = parseFloat((charged * commissionRate).toFixed(2));
      const ownerPayout = parseFloat((charged - platformCommission).toFixed(2));
      const bookingRef = db.collection("bookings").doc();

      // 3e. Atomic transaction: lock check + booking creation
      try {
        await db.runTransaction(async (tx) => {
          const txSlotDocs = await Promise.all(slotRefs.map((r) => tx.get(r)));
          const now = admin.firestore.Timestamp.now();

          for (const doc of txSlotDocs) {
            if (!doc.exists) {
              throw new Error(`Slot ${doc.id} not found`);
            }
            const data = doc.data()!;
            // Webhook path: accept booked or locked by this player
            if (data.status === "booked") continue; // already booked (race with verifyAndBook)
            if (data.status !== "locked" || data.lockedBy !== playerId) {
              throw new Error(`Slot ${doc.id} is not locked by player ${playerId}`);
            }
            const expiry = data.holdExpiry as admin.firestore.Timestamp | string;
            const expiryMs =
              typeof expiry === "string"
                ? new Date(expiry).getTime()
                : (expiry as admin.firestore.Timestamp).toMillis();
            if (expiryMs < now.toMillis()) {
              throw new Error("Slot hold expired");
            }
          }

          // Coupon usage increment (only if coupon applied and not yet counted)
          if (couponRefForTx && couponCode && couponDocId) {
            const couponTx = await tx.get(couponRefForTx);
            const usageCount: number = couponTx.data()?.usageCount ?? 0;
            const usageLimit: number = couponTx.data()?.usageLimit ?? 100;
            if (usageCount < usageLimit) {
              tx.update(couponRefForTx, {
                usageCount: admin.firestore.FieldValue.increment(1),
              });
              const usageLogRef = db.collection("coupon_usages").doc();
              tx.set(usageLogRef, {
                couponId: couponDocId,
                couponCode: couponCode.toUpperCase(),
                playerId,
                bookingId: bookingRef.id,
                discountApplied: discount,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }

          for (const ref of slotRefs) {
            tx.update(ref, { status: "booked", lockedBy: null, holdExpiry: null });
          }

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
            paymentVerifiedBy: "webhook",
          };
          if (discount > 0) {
            bookingData.discountedPrice = charged;
            bookingData.couponCode = couponCode!.toUpperCase();
          }
          tx.set(bookingRef, bookingData);

          tx.update(db.collection("pending_orders").doc(razorpayOrderId), {
            status: "processed",
            bookingId: bookingRef.id,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedBy: "webhook",
          });
        });

        console.log(
          `[webhook] Booking ${bookingRef.id} created via webhook for payment ${razorpayPaymentId}`
        );
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`[webhook] Booking creation failed: ${msg}`);
        // Issue refund — payment captured but booking could not be created
        await _attemptRefund(razorpayPaymentId, msg, playerId, slotIds, db);
      }

      res.status(200).send("OK");
      return;
    }

    // ── 4. Handle payment.failed ───────────────────────────────────────────
    if (event.event === "payment.failed") {
      const errCode = paymentEntity.error_code ?? "unknown";
      const errDesc = paymentEntity.error_description ?? "";

      console.log(
        `[webhook] payment.failed: ${razorpayPaymentId} — ${errCode}: ${errDesc}`
      );

      // Retrieve playerId from pending_orders
      const pendingOrderSnap = await db
        .collection("pending_orders")
        .doc(razorpayOrderId)
        .get();
      const playerId: string = pendingOrderSnap.data()?.playerId ?? "unknown";

      await db.collection("payment_attempts").add({
        razorpayOrderId,
        razorpayPaymentId,
        playerId,
        status: "failed",
        errorCode: errCode,
        errorDescription: errDesc,
        source: "webhook",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send("OK");
      return;
    }

    // Ignore other events
    res.status(200).send("Event ignored");
  }
);
