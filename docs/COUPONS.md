# Coupons — Full Spec & Implementation Backlog

## Current State (what's already built)

| Area | Status |
|------|--------|
| `Coupon` entity + `CouponModel` | ✅ Done |
| Owner creates coupons (code, type, value, expiry, limit, restricted emails) | ✅ Done |
| Owner deletes coupons | ✅ Done |
| Player applies promo code at checkout (client-side validation) | ✅ Done |
| Discount reflected in checkout summary UI | ✅ Done |
| `couponCode` passed to `createOrder` Cloud Function | ✅ Done |
| Server-side coupon validation in `createOrder` (expiry, email, usage pre-check) | ✅ Done |
| Razorpay order created with discounted amount | ✅ Done |
| Atomic `usageCount` increment in `verifyAndBook` transaction | ✅ Done |
| `coupon_usages` audit collection (per-redemption log) | ✅ Done |
| Firestore security rules for `coupons` and `coupon_usages` | ✅ Done |

---

## Known Bug — Checkout button shows original amount

### Symptom
After a player applies a coupon code:
- The booking summary card correctly shows the discount row and discounted "Total Payable"
- BUT the "Pay ₹X" button at the bottom still shows the original (non-discounted) amount
- AND the Razorpay payment screen also shows the original amount

### Root cause
`_discount` state is set correctly by `setState` in `_applyPromo`, and `_total = _subtotal - _discount`
is a computed getter — both the summary card and the button read `_total`.  
The discrepancy only makes sense if `_discount` is being computed in rupees on the Flutter side
but the Razorpay order amount from the server is in paise *before* the discount is subtracted —
i.e., the `couponCode` is reaching `createOrder` but the server's coupon lookup silently fails
(coupon not found / wrong code format), so `discountedAmountInPaise = subtotalInPaise` (no change),
and the returned `data['amount']` equals the full subtotal in paise.

Flutter's button text uses the **client-side** `_total` (which IS discounted), so the button
actually shows the right amount. The problem is that the **Razorpay gateway** shows the full amount
because the Razorpay order was created server-side for the full amount.

The player then sees: Flutter button says "Pay ₹800" but Razorpay says "₹1000" — confusing.

### Fix (to implement)
1. **Return `discountApplied` from `createOrder`** (already in response: `discountApplied: Number(couponDiscount)`)  
2. **Validate on the Flutter side that the server applied the expected discount** — compare
   `data['discountApplied']` to the client-computed `_discount * 100` (convert rupees → paise).
   If there's a mismatch, show an error: "Coupon could not be applied server-side. Please try again."
3. **Surface server-side coupon rejection to the user** — currently `createOrder` silently ignores
   invalid coupons (no error thrown). Add a dedicated error response for coupon failures so Flutter
   can show a meaningful message instead of silently charging full price.

### Files to touch
- `functions/src/createOrder.ts` — throw `HttpsError('invalid-argument', 'Coupon not applicable')` instead of silently ignoring
- `lib/presentation/screens/checkout_screen.dart` — after `createOrder` returns, check `data['discountApplied']` matches expected discount

---

## Gaps to Implement

### P0 — Bug fix (above) + missing data fields

#### 1. `usageCount` missing from `Coupon` entity
- `verifyAndBook` atomically increments `usageCount` in Firestore
- Dart `Coupon` entity has no `usageCount` field → owner cannot see redemption count in UI
- **Fix:** Add `final int usageCount` (default 0) to `Coupon` entity and `CouponModel.fromJson`

#### 2. `couponCode` missing from `Booking` entity
- `verifyAndBook` writes `couponCode` into the Firestore booking document
- Dart `Booking` entity has no `couponCode` field → players cannot see which coupon they used on receipt/history
- **Fix:** Add `final String? couponCode` to `Booking` entity and `BookingModel.fromJson`

---

### P1 — Owner dashboard improvements

#### 3. Coupon status badge (Active / Expired / Exhausted)
- Owner sees all coupons with no visual differentiation
- **Design decision:** Show a coloured badge:
  - `Active` (green) — `validTo >= now` AND `usageCount < usageLimit`
  - `Expired` (grey) — `validTo < now`
  - `Exhausted` (orange) — `usageCount >= usageLimit`
- Exhausted and expired coupons stay in the list (owners want history) but are visually de-emphasised

#### 4. Edit coupon
- Owners can create and delete but cannot modify after creation
- **Design decision:** Allow editing ONLY: `validTo`, `usageLimit`, `restrictedEmails`
  - `code`, `discountType`, `discountValue` are **immutable** once created — changing discount mid-life breaks player expectations if the code has already been shared
- UI: Edit icon on each coupon card → opens same dialog pre-filled with current values (minus code/type/value fields, which are read-only)
- **Files:** `owner_dashboard_screen.dart` — `_showEditCouponDialog()`, call `saveCoupon` with merge

#### 5. Usage counter on coupon card
- After adding `usageCount` to entity, display `X / Y uses` on each coupon card
- Requires `usageCount` field to be populated (see P0 item 1)

---

### P2 — Analytics

#### 6. Coupon redemption details
- `coupon_usages` collection has full audit trail (couponId, playerId, bookingId, discountApplied, createdAt)
- **Design decision:** Show as an expandable panel on each coupon card (NOT a separate screen — keeps it simple)
  - Tapping a coupon card expands it to show: total redemptions, total discount given (₹), last used date
  - No per-user list in MVP (privacy + complexity)
- **Requires:** A new Firestore query in `venue_repository_impl.dart`: `watchCouponUsages(couponId)`
- **Requires:** New Firestore index: `coupon_usages(couponId ASC, createdAt DESC)`

#### 7. Coupon code shown on player receipt and booking card
- After adding `couponCode` to `Booking` entity (P0 item 2):
  - Show "Coupon applied: SAVE20" on the receipt screen
  - Show coupon badge on booking card in player bookings list
- **Files:** `receipt_screen.dart`, `player_bookings_screen.dart`

#### 8. Coupon shown in owner's booking view
- Owner dashboard booking list: show a coupon tag (e.g. "SAVE20 — ₹200 off") on bookings where a coupon was used
- **Files:** owner's bookings section in `owner_dashboard_screen.dart`

---

## Design Decisions (answered)

| Question | Decision |
|----------|----------|
| Edit coupon — which fields? | Only `validTo`, `usageLimit`, `restrictedEmails`. Code/type/value are immutable. |
| Exhausted coupons — hide or badge? | Keep in list with "Exhausted" badge. Owners need history. |
| Coupon analytics — separate screen or panel? | Expandable panel on each coupon card. Simpler, no new route needed. |
| Player-facing "X uses remaining" counter? | No. Current "coupon applied ✓" is enough. Showing remaining uses is complex and can feel manipulative. |

---

## Data Model Reference

### Firestore `coupons/{couponId}`
```
id            String
ownerId       String
code          String       (stored UPPERCASE)
discountType  String       "percentage" | "flat"
discountValue Number       (rupees for flat, 0-100 for percentage)
validTo       Timestamp
usageLimit    Number       (default 100)
usageCount    Number       (incremented atomically by verifyAndBook)
restrictedEmails  Array<String>?
```

### Firestore `coupon_usages/{usageId}`
```
couponId        String
couponCode      String
playerId        String
bookingId       String
discountApplied Number     (rupees)
createdAt       Timestamp
```

### Dart `Coupon` entity (current gaps marked)
```dart
id, ownerId, code, discountType, discountValue, validTo, usageLimit, restrictedEmails
// MISSING: usageCount (P0)
```

### Dart `Booking` entity (current gaps marked)
```dart
id, playerId, venueId, zoneId, slotIds, date, startTime, endTime, createdAt,
totalPrice, discountedPrice, platformCommission, ownerPayout,
venueName, venueLocation, zoneName, sportType, playerName, playerPhone,
razorpayOrderId, razorpayPaymentId, razorpaySignature, paymentMethod, status, settlementStatus
// MISSING: couponCode (P0)
```

---

## Implementation Order

```
1. Fix bug: createOrder throws on coupon failure + Flutter validates server discount ack
2. Add usageCount to Coupon entity + CouponModel
3. Add couponCode to Booking entity + BookingModel
4. Show usageCount + status badge on owner coupon cards
5. Show couponCode on receipt screen + player booking card
6. Edit coupon dialog (validTo / usageLimit / restrictedEmails only)
7. Coupon usage analytics panel (coupon_usages query)
8. Show coupon in owner's booking view
```
