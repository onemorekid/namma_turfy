# Code Improvements Backlog

Non-functional improvements only — no feature changes, no behaviour changes.
Grouped by priority. Each item is self-contained and safe to ship independently.

---

## Priority 1 — Critical (Security / Data Integrity)

### I-01 · Never log signatures or secrets
**File:** `functions/src/verifyAndBook.ts`  
**Issue:** A debug `console.log` prints a substring of the Razorpay HMAC signature.
Signatures must never appear in logs — even truncated.  
**Fix:** Remove or replace the log line with a safe message like
`"[verifyAndBook] Signature check passed"`.

---

### I-02 · Refund idempotency guard
**File:** `functions/src/verifyAndBook.ts` — `_attemptRefund()`  
**Issue:** If `verifyAndBook` is retried (e.g., client timeout + re-call), the auto-refund
block can issue a second refund for the same `paymentId`.  
**Fix:** Before calling Razorpay refund API, query `orphaned_payments/{paymentId}`.
If document already exists with `refundStatus != null`, skip the refund and return early.

---

### I-03 · Payout deduplication in settleOwnerPayouts
**File:** `functions/src/settleOwnerPayouts.ts`  
**Issue:** If the scheduled function runs twice in the same settlement window
(e.g., Cloud Scheduler retry), the same venue could be paid out twice.  
**Fix:** Before creating a payout, check `settlement_records` for an existing record
with the same `venueId` + settlement period. Skip if found.

---

### I-04 · Validate RAZORPAY_PAYOUT_ACCOUNT before using it
**File:** `functions/src/settleOwnerPayouts.ts` line ~105  
**Issue:** `process.env.RAZORPAY_PAYOUT_ACCOUNT!` uses a non-null assertion.
If the secret is missing, the payout call silently sends to undefined.  
**Fix:**
```typescript
const payoutAccount = process.env.RAZORPAY_PAYOUT_ACCOUNT;
if (!payoutAccount) throw new Error("RAZORPAY_PAYOUT_ACCOUNT secret not set");
```

---

### I-05 · Validate slotIds array size in createOrder
**File:** `functions/src/createOrder.ts`  
**Issue:** No upper bound on `slotIds.length`. A malicious caller could send 500+ slot IDs,
causing excessive Firestore reads and hitting quota limits.  
**Fix:** Add `if (slotIds.length > 10) throw HttpsError('invalid-argument', 'Too many slots');`

---

### I-06 · Coupon ID collision risk
**File:** `lib/presentation/screens/owner_dashboard_screen.dart` line ~1152  
**Issue:** `'cpn_${DateTime.now().millisecondsSinceEpoch}'` can collide if two coupons are
created within the same millisecond.  
**Fix:** Use `_firestore.collection('coupons').doc().id` (Firestore auto-ID) instead.

---

### I-07 · Dialog controllers never disposed
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** Every `showDialog` creates multiple `TextEditingController` instances inline
(lines ~98, ~287, ~407, ~711, ~1052, ~1181). When dialog is dismissed, these are never disposed.  
**Fix:** Wrap each dialog body in a `StatefulWidget` so controllers can be disposed
in `dispose()`. Or create and dispose them in the parent state, not inside the builder.

---

## Priority 2 — High (UX / Core Quality)

### I-08 · Replace all hardcoded colors with AppColors constants
**Files:** 40+ files across the codebase  
**Issue:** `Color(0xFF35CA67)` (primary green) appears 40+ times.
`Color(0xFF1E88E5)` (blue), `Colors.red[800]`, etc. scattered everywhere.  
**Fix:**
1. Create `lib/core/theme/app_colors.dart` (spec in `STYLE_GUIDE.md` section 1)
2. Global find-and-replace:
   - `Color(0xFF35CA67)` → `AppColors.primary`
   - `Color(0xFF1E88E5)` → `AppColors.info`
   - `Colors.red[800]` → `AppColors.error`
   - `Colors.grey[300]` → `AppColors.outline`
   - `Colors.grey[600]` → `AppColors.onSurfaceVar`

---

### I-09 · Extract all magic numbers to constants
**Files:** Multiple  
**Fix:** Create `lib/core/constants/app_constants.dart`:
```dart
class AppConstants {
  // Payments
  static const int minAmountPaise      = 100;
  static const int slotLockMinutes     = 10;
  static const int maxSlotsPerBooking  = 10;
  static const double defaultSlotPrice = 500.0;
  static const int defaultCommission   = 5; // percent

  // Validation
  static const int minPhoneLength      = 10;
  static const int maxPhoneLength      = 15;
  static const int maxCouponCodeLength = 20;
  static const int maxVenueNameLength  = 80;

  // Firestore
  static const int firestoreBatchSize  = 490;

  // URLs
  static const String verifyBaseUrl    = 'https://turfy-7e791.web.app/verify/';
}
```
Replace every matching literal across codebase.

---

### I-10 · Friendly error messages — replace raw exceptions shown to users
**Files:** Multiple  
**Issue:** Several screens do `Text('Error: $e')` or pass `e.toString()` directly to users.
Users see Dart exception stack traces or Firebase internal codes.  
**Fix:** Create `lib/core/utils/error_formatter.dart`:
```dart
String friendlyError(dynamic error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated'    => 'Please sign in again.',
      'failed-precondition'=> 'Slot hold expired. Please select slots again.',
      'resource-exhausted' => 'Coupon limit reached.',
      'not-found'          => 'Item not found. It may have been deleted.',
      'permission-denied'  => 'You don\'t have permission for this action.',
      _                    => error.message ?? 'Something went wrong.',
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'popup-blocked'       => 'Sign-in popup was blocked. Try again.',
      'popup-closed-by-user'=> 'Sign-in was cancelled.',
      _                    => 'Sign-in failed. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
```
Replace all `Text('Error: $e')` and raw `e.toString()` in:
- `home_screen.dart` line ~201
- `player_bookings_screen.dart` line ~47
- `venue_details_screen.dart` error states
- `owner_dashboard_screen.dart` lines ~199, ~382, ~479, ~880
- `checkout_screen.dart` error snackbars

---

### I-11 · Add input validation to all forms
**Files:** Multiple  
**Issue:** Forms accept empty strings, 0-value prices, invalid phone numbers.  
**Fix:** Create `lib/core/utils/validators.dart`:
```dart
class Validators {
  static String? phone(String? v) {
    if (v == null || v.isEmpty) return 'Phone number is required';
    if (v.length < AppConstants.minPhoneLength) return 'Enter a valid phone number';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Only digits allowed';
    return null;
  }
  static String? couponCode(String? v) {
    if (v == null || v.isEmpty) return 'Enter a coupon code';
    if (v.length > AppConstants.maxCouponCodeLength) return 'Code too long';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v)) return 'Only letters and numbers';
    return null;
  }
  static String? venueName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Venue name is required';
    if (v.length > AppConstants.maxVenueNameLength) return 'Name too long';
    return null;
  }
  static String? price(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Price must be greater than 0';
    return null;
  }
  static String? discountValue(String? v, DiscountType type) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Discount must be greater than 0';
    if (type == DiscountType.percentage && n > 100) return 'Cannot exceed 100%';
    return null;
  }
}
```
Apply to:
- `profile_completion_screen.dart` — phone field
- `owner_dashboard_screen.dart` — venue name, zone name, slot price, coupon code + value
- `checkout_screen.dart` — promo code field

---

### I-12 · Add logout confirmation dialog
**File:** `lib/presentation/widgets/app_drawer.dart` line ~125  
**Issue:** Tapping "Logout" signs the user out immediately with no confirmation.
On mobile this is easy to trigger accidentally.  
**Fix:**
```dart
onTap: () {
  Navigator.pop(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Sign out?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ref.read(authRepositoryProvider).signOut();
          },
          child: const Text('Sign out', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
},
```

---

### I-13 · Add confirmation dialogs for destructive delete actions
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** Delete slot and delete coupon fire immediately on tap.  
**Locations:** Slot delete button (~line 610), coupon delete button (~line 1066)  
**Fix:** Wrap each delete call in a `showDialog` with Cancel / Delete buttons.
Delete button text in red. Only call the delete method if confirmed.

---

### I-14 · Add success snackbars after state-changing actions
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** Several actions succeed silently — no visual feedback to owner.  
**Locations and messages:**
- Toggle slot status → `"Slot marked as [status]"`
- Save venue details → `"Venue updated"`
- Save zone → `"Zone saved"`
- Generate slots → already has feedback ✅
- Delete slot → `"Slot deleted"` (after confirmation from I-13)
- Delete coupon → `"Coupon deleted"` (after confirmation from I-13)

---

### I-15 · Define route path constants
**File:** `lib/core/router/router.dart`  
**Issue:** Path strings like `'/login'`, `'/venue/:id'`, `'/receipt/:id'` are duplicated
across router + `context.go()` / `context.push()` calls throughout the app.
One typo causes a silent no-op navigate.  
**Fix:**
```dart
class AppRoutes {
  static const splash        = '/splash';
  static const login         = '/login';
  static const home          = '/';
  static const venue         = '/venue';
  static const checkout      = '/checkout';
  static const receipt       = '/receipt';
  static const myBookings    = '/my-bookings';
  static const contact       = '/contact';
  static const owner         = '/owner';
  static const admin         = '/admin';
  static const payCallback   = '/payment-callback';
  // helpers
  static String venueDetail(String id) => '$venue/$id';
  static String receiptDetail(String id) => '$receipt/$id';
}
```
Replace all `context.go('/...')` strings with `AppRoutes.*`.

---

### I-16 · Show loading indicator during image upload
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** Image upload is async but the dialog shows no progress. User taps "Add"
and nothing visual happens until the upload completes (could be 5-10 seconds).  
**Fix:** Add a `bool _isUploading` state variable to the dialog. Show a
`LinearProgressIndicator` or `CircularProgressIndicator` while uploading.
Disable the upload button during upload.

---

### I-17 · Null-safe router path parameter extraction
**File:** `lib/core/router/router.dart` lines ~111, ~141, ~156  
**Issue:** `state.pathParameters['venueId']!` throws if the parameter is missing.  
**Fix:**
```dart
final venueId = state.pathParameters['venueId'];
if (venueId == null || venueId.isEmpty) return const ErrorScreen();
```

---

## Priority 3 — Medium (Performance / Polish)

### I-18 · Cache sport categories derived value in a provider
**File:** `lib/presentation/screens/home_screen.dart`  
**Issue:** The list of unique sport categories is computed with `expand().toSet().sort()`
on every widget rebuild.  
**Fix:** Add a derived `allSportCategoriesProvider` using Riverpod's `Provider`:
```dart
final allSportCategoriesProvider = Provider<List<String>>((ref) {
  final venues = ref.watch(venuesStreamProvider).value ?? [];
  return venues.expand((v) => v.sportsTypes).toSet().toList()..sort();
});
```

---

### I-19 · Paginate player bookings
**File:** `lib/data/repositories/booking_repository_impl.dart` + `lib/presentation/screens/player_bookings_screen.dart`  
**Issue:** `watchPlayerBookings` loads ALL of a player's bookings in one stream.
A frequent user with 200+ bookings will have unnecessary memory and bandwidth usage.  
**Fix:** Add a `.limit(20)` to the initial query and implement infinite scroll
using `startAfterDocument` for the next page. Use a `ScrollController` in
`player_bookings_screen.dart` to trigger fetching the next page near the bottom.

---

### I-20 · Cache ThemeData construction
**File:** `lib/main.dart` line ~43  
**Issue:** `ThemeData(...)` and `GoogleFonts.outfitTextTheme(...)` are rebuilt on
every `MainApp.build()` call (e.g., every auth state change).  
**Fix:** Hoist the theme into a static or top-level variable:
```dart
// Outside MainApp class
final _appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, ...),
  textTheme: GoogleFonts.outfitTextTheme(),
  ...
);
```

---

### I-21 · Add splash screen timeout / error fallback
**File:** `lib/presentation/screens/splash_screen.dart`  
**Issue:** If Firebase auth stream never emits (e.g., network offline at cold start),
user sees the splash spinner forever.  
**Fix:** Add a 6-second timeout. If auth state is still loading after 6s, navigate to
`/login` with a "No connection" banner.

---

### I-22 · Cache Google logo asset locally
**File:** `lib/presentation/screens/login_screen.dart` line ~50  
**Issue:** Google logo is fetched from `upload.wikimedia.org` on every login screen load.
Fails silently on no-internet (shows a fallback icon). Adds latency.  
**Fix:** Download the Google logo SVG/PNG, add to `assets/images/google_logo.png`,
register in `pubspec.yaml`, use `Image.asset(...)` instead.

---

### I-23 · Add keyboard scroll padding to forms
**Files:** `profile_completion_screen.dart`, `checkout_screen.dart`, owner dialog forms  
**Issue:** When keyboard opens on mobile, input fields near the bottom are obscured.  
**Fix:** Wrap scrollable content in `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), ...)` 
or use `resizeToAvoidBottomInset: true` (already default but verify) and ensure
`SingleChildScrollView` is present around form content in all dialog bodies.

---

### I-24 · Add retry button to all error states
**Files:** `home_screen.dart`, `player_bookings_screen.dart`, `venue_details_screen.dart`  
**Issue:** When a stream errors, user sees the error message but has no way to retry
without closing and reopening the screen.  
**Fix:** Replace:
```dart
error: (e, _) => Center(child: Text('Error: $e'))
```
with:
```dart
error: (e, _) => Center(
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
    const SizedBox(height: 12),
    Text(friendlyError(e), style: ..., textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      onPressed: () => ref.invalidate(relevantProvider),
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  ]),
)
```

---

### I-25 · Add debounce to rapid-fire write actions
**Files:** `owner_dashboard_screen.dart`, `admin_dashboard_screen.dart`  
**Issue:** Toggling a slot status or commission rate has no debounce — rapid taps
create multiple Firestore writes.  
**Fix:** Use a simple debounce pattern:
```dart
Timer? _debounce;
void _debouncedUpdate(VoidCallback fn) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 500), fn);
}
```
Apply to slot status toggle, commission rate save, role toggle in admin.

---

### I-26 · Add `const` constructors where missing
**Files:** All widget files  
**Issue:** Many leaf widgets (icons, text, padding) are not `const` even though they can be.
This prevents Flutter from skipping unnecessary rebuilds.  
**Fix:** Run `flutter analyze` with `prefer_const_constructors` lint enabled.
The analyzer will flag every place `const` can be added.
Add to `analysis_options.yaml`:
```yaml
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
```

---

### I-27 · Add accessibility semantic labels to icon buttons
**Files:** `home_screen.dart`, `app_drawer.dart`, `venue_details_screen.dart`  
**Issue:** `IconButton`s have no `tooltip` or `semanticLabel`. Screen readers
announce "button" with no context.  
**Fix:** Add `tooltip:` to every `IconButton`:
```dart
IconButton(
  tooltip: 'Notifications',
  icon: const Icon(Icons.notifications_none),
  onPressed: ...,
)
```

---

### I-28 · Fix releaseExpiredLocks time comparison
**File:** `functions/src/releaseExpiredLocks.ts` line ~22  
**Issue:** `const now = new Date().toISOString()` creates a string but slot
`holdExpiry` is a Firestore Timestamp compared with `.toMillis()`. The types
are inconsistent — the ISO string comparison works coincidentally because ISO
strings sort lexicographically, but it's fragile.  
**Fix:**
```typescript
const nowMs = Date.now();
// then: slot.holdExpiry.toMillis() <= nowMs
```

---

### I-29 · Extract releaseExpiredLocks batch size to constant
**File:** `functions/src/releaseExpiredLocks.ts` line ~55  
**Issue:** Magic number `490` for Firestore batch chunk size.  
**Fix:**
```typescript
const FIRESTORE_BATCH_LIMIT = 490; // Firestore max is 500, leave headroom
```

---

### I-30 · Move ThemeData out of main.dart into its own file
**File:** `lib/main.dart`  
**Issue:** `main.dart` contains business logic (theme, scroll behaviour).  
**Fix:** Create `lib/core/theme/app_theme.dart` and export `appTheme`:
```dart
final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  useMaterial3: true,
  ...
);
```
`main.dart` becomes: `theme: appTheme`.

---

## Priority 4 — Low (Code Quality / Maintainability)

### I-31 · Add Firebase init error handling in main()
**File:** `lib/main.dart`  
**Issue:** `Firebase.initializeApp()` is awaited but no catch. If it throws,
app crashes with an unreadable error.  
**Fix:**
```dart
try {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
} catch (e) {
  runApp(const FirebaseInitErrorApp()); // Simple "Update the app" screen
  return;
}
```

---

### I-32 · Owner dashboard: extract repeated dialog patterns
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** Venue create, zone create, venue edit, zone edit dialogs share identical
structure (title, scrollable form, Cancel/Save actions) but are written separately
(~300 lines of duplication).  
**Fix:** Extract a reusable `_FormDialog` widget:
```dart
class _FormDialog extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final VoidCallback onSave;
  // ...
}
```

---

### I-33 · Use consistent ID generation strategy
**File:** `lib/presentation/screens/owner_dashboard_screen.dart`  
**Issue:** IDs are generated with `DateTime.now().millisecondsSinceEpoch`
(collision-prone). Firestore's auto-IDs are safer.  
**Fix:** Replace `'cpn_${DateTime.now().millisecondsSinceEpoch}'` with
`_firestore.collection('coupons').doc().id` for all entity ID generation.

---

### I-34 · Remove unused import / dead file check
**Files:** Various  
**Fix:** Run `flutter analyze` and check for any `unused_import` warnings.
Also verify `event_discovery_screen.dart` is still reachable in the router.
If not, delete the file.

---

### I-35 · Add max-length to all TextFields
**Files:** All form-containing screens  
**Issue:** No `maxLength` or `inputFormatters` on text fields. A user can paste
10 KB of text into a "Venue Name" field and it will be stored in Firestore.  
**Fix:** Add `maxLength:` to every `TextField`/`TextFormField`:
```
Venue name:        80 chars
Zone name:         60 chars
Promo code:        20 chars
Emails (textarea): 500 chars
Phone number:      15 chars
Slot price:        7 digits
Usage limit:       6 digits
```

---

### I-36 · Consistent snackbar helper
**Files:** Multiple  
**Issue:** Snackbar creation is copy-pasted across screens with different styles.  
**Fix:** Create `lib/core/utils/snackbars.dart`:
```dart
void showSuccessSnackbar(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary));

void showErrorSnackbar(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));
```

---

## Implementation Order (suggested)

```
Phase A — Foundation (do first, everything else depends on it)
  I-08  Extract AppColors
  I-09  Extract AppConstants
  I-10  Add error formatter
  I-36  Add snackbar helpers

Phase B — Safety
  I-01  Remove secret logging
  I-02  Refund idempotency
  I-03  Payout deduplication
  I-04  Validate PAYOUT secret
  I-05  Limit slotIds size
  I-06  Fix coupon ID collision
  I-07  Fix dialog controller leaks

Phase C — UX Polish
  I-11  Form validation everywhere
  I-12  Logout confirmation
  I-13  Delete confirmation dialogs
  I-14  Success snackbars
  I-16  Image upload progress
  I-24  Retry buttons on error states

Phase D — Performance
  I-18  Cache sport categories in provider
  I-19  Paginate player bookings
  I-20  Cache ThemeData
  I-25  Debounce rapid writes
  I-26  Add const constructors

Phase E — Code Quality
  I-15  Route path constants
  I-17  Safe router param extraction
  I-21  Splash timeout
  I-22  Bundle Google logo
  I-30  Move theme to own file
  I-31  Firebase init error handling
  I-32  Extract dialog patterns
  I-33  Consistent ID generation
  I-34  Dead code cleanup
  I-35  TextField max lengths
```

**Total estimated effort:** ~20–25 hours of focused work, shippable in small independent PRs.
