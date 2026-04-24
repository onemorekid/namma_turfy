import * as admin from "firebase-admin";
import { createOrder } from "./createOrder";
import { verifyAndBook } from "./verifyAndBook";
import { releaseExpiredLocks } from "./releaseExpiredLocks";
import { razorpayWebhook } from "./razorpayWebhook";
// settleOwnerPayouts intentionally disabled — owner payouts are distributed manually.
// The ownerPayout + platformCommission fields remain in Firestore booking documents for tracking.

import { onSlotStatusChange } from "./onSlotStatusChange";

admin.initializeApp();

export {
  createOrder,
  verifyAndBook,
  releaseExpiredLocks,
  razorpayWebhook,
  onSlotStatusChange,
};
