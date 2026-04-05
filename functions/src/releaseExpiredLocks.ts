import * as functions from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

/**
 * releaseExpiredLocks — runs every 2 minutes via Cloud Scheduler.
 *
 * Finds all slots with status=locked where holdExpiry < now,
 * and resets them to status=available so other players can book them.
 *
 * This handles the case where a player:
 *   - Locks slots, goes to checkout, then abandons / app crashes
 *   - Lock naturally expires after 10 minutes
 */
export const releaseExpiredLocks = functions.onSchedule(
  "every 2 minutes",
  async () => {
    const db = admin.firestore();
    const now = new Date().toISOString();

    // Query locked slots whose holdExpiry is in the past
    // Firestore doesn't support < on string dates reliably across formats,
    // so we fetch all locked slots and filter in memory (low volume expected).
    const snapshot = await db
      .collection("slots")
      .where("status", "==", "locked")
      .get();

    if (snapshot.empty) return;

    // Collect all docs that need releasing
    const toRelease: admin.firestore.QueryDocumentSnapshot[] = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const expiryRaw = data.holdExpiry;
      if (!expiryRaw) {
        // No expiry set — release it
        toRelease.push(doc);
        continue;
      }

      const expiryMs =
        expiryRaw instanceof admin.firestore.Timestamp
          ? expiryRaw.toMillis()
          : new Date(expiryRaw as string).getTime();

      if (expiryMs < Date.now()) {
        toRelease.push(doc);
      }
    }

    if (toRelease.length === 0) return;

    // Chunk into groups of 490 to avoid the 500-document Firestore batch limit
    const CHUNK_SIZE = 490;
    for (let i = 0; i < toRelease.length; i += CHUNK_SIZE) {
      const chunk = toRelease.slice(i, i + CHUNK_SIZE);
      const batch = db.batch();
      for (const doc of chunk) {
        batch.update(doc.ref, {
          status: "available",
          lockedBy: null,
          holdExpiry: null,
        });
      }
      await batch.commit();
    }

    console.log(`Released ${toRelease.length} expired slot locks at ${now}`);
  }
);
