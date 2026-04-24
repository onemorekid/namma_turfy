# Feature Definitions

Pre-development spec for the next batch of improvements.
Each section covers: what to build, data model changes, open questions, and implementation notes.

---

## F-01 · App Version on UI

### What to build
Display the app version and build number in two places:
- **Profile tab** (home screen) — bottom of the profile section, small grey label: `v1.0.0 (42)`
- **App Drawer** — below the user name/email, same small label

### Implementation
- Use the `package_info_plus` package (`PackageInfo.fromPlatform()`) to read `version` and `buildNumber` at runtime
- Create a `packageInfoProvider` (FutureProvider) so it's loaded once and cached
- Format: `v{version} ({buildNumber})`
- Style: `AppTextStyles.bodySmall` in `AppColors.onSurfaceVar` — unobtrusive

### Data changes
None.

---

## F-02 · Venue & Zone Creation — Richer Form + Map Location

### What to build

**Venue creation/edit** replaces the current dialog with a full-screen `BottomSheet` or `DraggableScrollableSheet` (single scrollable page, not a multi-step wizard). Sections in order:

1. **Basic info** (all mandatory)
   - Venue name (max 80 chars)
   - Venue type (dropdown: Football, Cricket, Badminton, Multi-sport…)
   - Sports offered (multi-select chips)
   - Description (multiline, max 300 chars)

2. **Location** (mandatory)
   - A "Search location" field with autocomplete (Google Places API)
   - Below it, an embedded `GoogleMap` widget showing a draggable pin
   - When the owner selects a place from autocomplete OR drags the pin, the `latitude`, `longitude`, `location` (address string), and `city` fields are auto-populated
   - The owner must confirm location before saving — the Save button is disabled until a location is set

3. **Photos** (at least 1 required)
   - Horizontal scroll strip showing thumbnails of uploaded images
   - "+ Add photo" button using `image_picker`
   - Each thumbnail has an ✕ to remove
   - Shows upload progress per image

4. **Pricing & hours**
   - Base price per hour (used as default for slot generation)
   - Operating hours: open time → close time (time range picker)
   - Peak hour windows (see F-04 for detail)

5. **Policies** (optional)
   - General instructions (multiline)
   - Cancellation policy (multiline)
   - Rules (add/remove chips)

**Validation before save:**
- Name not empty and ≤ 80 chars
- At least one sport type selected
- Location confirmed (lat/lng not 0,0)
- At least one photo uploaded
- Base price > 0
- Operating hours: close > open

**Zone creation/edit** also becomes a more complete form:
1. Zone name (mandatory, max 60 chars)
2. Sport type (dropdown, inherits from venue but overridable)
3. Photos (at least 1 required) — same upload strip as venue
4. Capacity (optional — number of players the zone fits)

**Zone photo bug fix:**
When a zone photo is uploaded and saved, the first zone image URL must also be written into the parent `venue.images` array in Firestore (if the venue has no images yet, or as an additional image). This ensures the venue card on the home screen always has at least one displayable image. The write happens in the same Firestore batch as the zone save.

Specifically: after uploading zone photos, if `venue.images` is empty, set `venue.images = [firstZoneImageUrl]`. If `venue.images` is not empty, append the new zone image to it. Use `FieldValue.arrayUnion` to avoid duplicates.

**Player side — open location in maps:**
When a player taps the venue location text (address line) on the venue detail screen, open the native maps app:
- Android: `geo:{lat},{lng}?q={encodedAddress}`
- iOS: `https://maps.apple.com/?q={encodedAddress}&ll={lat},{lng}`
- Use the `url_launcher` package (already likely in pubspec — confirm)

### Packages needed
- `flutter_map` — OpenStreetMap-based map widget, no API key required
- `latlong2` — coordinate type used by flutter_map
- `flutter_map_cancellable_tile_provider` — efficient tile loading/cancellation for flutter_map
- `geocoding` — reverse geocoding (coordinates → human-readable address string)
- `geolocator` — already in pubspec; used to get the device's current GPS position
- `url_launcher` — already in pubspec; used to open native maps app

**No API key needed.** Map tiles served from OpenStreetMap; address search via the free Nominatim REST API (`nominatim.openstreetmap.org/search`).

**Address autocomplete approach (Nominatim):**
`GET https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=5&countrycodes=in`
Returns a list of results with `display_name`, `lat`, `lon`. Debounce the search field at 500ms to stay within Nominatim's fair-use policy (max 1 req/s).

### Data model changes
`Venue` entity gets two new optional fields:
```dart
final TimeOfDay? openTime;   // venue operating start
final TimeOfDay? closeTime;  // venue operating end
```
Stored in Firestore as `openTimeHour`/`openTimeMinute` integers.
`Zone` entity gets:
```dart
final int? capacity;
```

### Map default behaviour
On opening the location picker, the map centers on the **device's current GPS position** (via `geolocator`) with the draggable pin dropped there. If GPS permission is denied or unavailable, fall back to a fixed center (Vijayapura, since that's the primary city). Reverse-geocode the initial GPS position immediately so the address field is pre-populated.

---

## F-03 · Slot Generation — Interactive & Error-Proof

### What to build

Replace the current slot generation form with an interactive slot builder:

**Step 1 — Configure generation**
- Date picker (single date or date range — "generate for the whole week")
- Start time / End time for the day (pre-filled from venue operating hours)
- Slot duration: 30 min / 1 hr / 90 min / 2 hr (segmented control)
- Base price (pre-filled from zone default)
- Peak hour overrides (auto-loaded from venue's peak settings — see F-04)

**Step 2 — Preview grid (before saving)**
After tapping "Preview", show a scrollable grid of all slots that would be generated:

| Time | Date | Price | Peak? | Action |
|------|------|-------|-------|--------|
| 6:00 AM – 7:00 AM | Mon 28 Apr | ₹800 | 🟠 | [Edit] [Remove] |
| 7:00 AM – 8:00 AM | Mon 28 Apr | ₹800 | 🟠 | [Edit] [Remove] |
| 5:00 PM – 6:00 PM | Mon 28 Apr | ₹900 | 🟠 | [Edit] [Remove] |

- Peak slots are highlighted with a different row color and a badge
- Owner can edit the price of individual slots inline before saving
- Owner can remove specific slots from the batch
- **Conflict detection**: before showing the preview, query Firestore for existing slots in the same zone + date range. Any slot that already exists is shown with a ⚠️ "Already exists" warning and excluded from the save batch. This prevents duplicates.

**Step 3 — Confirm & save**
- Summary: "X slots will be created across Y days"
- If conflicts: "Z slots skipped (already exist)"
- Single "Generate Slots" button commits the batch

### Conflict check logic
```
existingSlots = query slots where zoneId == zoneId
                AND startTime >= batchStartDate
                AND startTime <= batchEndDate
For each slot in preview:
  if existingSlots.any((s) => s.startTime == slot.startTime) → mark as conflict, exclude
```

### Data model changes
None to `Slot` entity. `Zone` gets a `defaultPrice` field (already has pricing via slot; just ensure it's pre-populated).

---

## F-04 · Peak Hours — Configurable Per Venue

### What to build

Owners can define two peak windows per venue:
- **Morning peak**: start time → end time (default: 06:00 → 10:00)
- **Evening peak**: start time → end time (default: 17:00 → 22:00)

These are configured in the Venue create/edit form (section 4, under "Pricing & hours").
UI: two rows of time-range pickers, labelled "Morning peak" and "Evening peak".
Each row has a toggle to disable that window entirely.

During slot generation (F-03), slots whose `startTime` falls within either peak window automatically get the **peak price** applied. The peak price = base price × peak multiplier (default 1.2×, configurable per venue in the same section).

**Display on player home screen:**
Peak slots already booked or available must visually indicate peak pricing on the venue detail / slot selection screen (orange badge, as already present in the UI).

### Data model changes
`Venue` entity additions:
```dart
final int morningPeakStartHour;   // default 6
final int morningPeakStartMinute; // default 0
final int morningPeakEndHour;     // default 10
final int morningPeakEndMinute;   // default 0
final int eveningPeakStartHour;   // default 17
final int eveningPeakStartMinute; // default 0
final int eveningPeakEndHour;     // default 22
final int eveningPeakEndMinute;   // default 0
final double peakMultiplier;      // default 1.2
```
Stored as flat integer fields in the `venues` Firestore document.

---

## F-05 · Player Home Screen — Minimum Slot Price on Venue Card

### What to build

Each `VenueCardWidget` on the home screen shows a price line:
- **"From ₹500 / hr"** — the minimum available (non-booked) slot price across all zones of that venue for today/upcoming slots

### How to compute
- Add a `minSlotPrice` field to the `Venue` Firestore document (denormalized, updated whenever slots are generated or prices change)
- Alternatively, query the cheapest available slot for each venue client-side — but this is expensive; prefer the denormalized field
- When slot generation runs, write `minSlotPrice = min(slot prices in this venue)` back to the venue document
- Display on the card: below the venue name / sport tags row

### Data model changes
`Venue` entity:
```dart
final double? minSlotPrice;
```

---

## F-06 · Home Screen Time Filter — Fix + Next 4 Hours Only

### What to build

**Bug fix:** The current time filter chips are not correctly filtering the venue list.
Root cause: `venue.availableHours` is a `List<String>` of hour strings (e.g. `["09", "10", "17"]`) but available slots are not being joined with this list correctly. The filter must instead query **actual available (non-booked) slots** for the selected hour, not just the venue's declared hours.

**Change: show only the next 4 hours**
The time filter chips on the home screen must show exactly 4 options:
- The current hour (if it's before :45 past the hour, otherwise skip to next)
- The next 3 consecutive hours

Example at 14:20 → chips: `2 PM  3 PM  4 PM  5 PM`
Example at 14:50 → chips: `3 PM  4 PM  5 PM  6 PM`

Format: `h a` (e.g. "2 PM", "6 AM")

**Filter behavior:**
When a chip is selected, show only venues that have at least one `available` slot starting in that hour on today's date. This requires either:
- A denormalized `availableSlotHours` field on each venue document (updated when slots are booked/released), **or**
- A Firestore query per venue for slots on today × selected hour — not scalable

Recommended: add a `availableSlotHours` field (`List<int>`) to each venue document. Updated by a Cloud Function trigger `onSlotStatusChange` whenever a slot's status changes (booked/released). The home screen filter reads this field.

### Data model changes
`Venue` entity:
```dart
final List<int> availableSlotHours; // hours (0–23) with at least one available slot today
```

---

## F-07 · Offers on Venue Card (Player Home Screen)

### What to build

Each venue card on the player home screen shows a small offers row at the bottom if the venue has active, unrestricted coupons.

**What counts as "generic" (show):**
- `coupon.restrictedEmails == null || coupon.restrictedEmails!.isEmpty`
- `coupon.validTo.isAfter(DateTime.now())`
- `coupon.usageCount < coupon.usageLimit`
- `coupon.ownerId == venue.ownerId` (belongs to this venue's owner)

**What to display:**
- If 1 coupon: `🏷 SAVE10 · 10% off`
- If 2+ coupons: `🏷 SAVE10 +2 offers`
- Tapping opens a bottom sheet listing all active offers for that venue with code + description

**Where to load:**
- Add a `venueOffersProvider(venueId)` — streams `coupons` collection filtered by `ownerId == venue.ownerId` where `validTo > now` and `restrictedEmails == []` (or missing field)
- On the home screen, each `VenueCardWidget` receives a pre-fetched list of active offers (fetched once per venue load, not per card render)

### Data model changes
None. Uses existing `Coupon` entity. The `restrictedEmails` field is already present — empty list = public, non-empty = restricted.

Firestore index needed:
```
Collection: coupons
Fields: ownerId (ASC), validTo (ASC)
```

---

## Implementation order (suggested)

```
1. F-06  Time filter fix (bug — highest user impact, self-contained)
2. F-05  Min slot price on venue card (denormalized field, low risk)
3. F-07  Offers on venue card (read-only, no data changes)
4. F-01  Version on UI (trivial, good confidence builder)
5. F-04  Peak hours config (data model + venue form section)
6. F-03  Slot generation overhaul (depends on F-04 peak config)
7. F-02  Venue/Zone form + map (largest scope, depends on API key decision)
```

---

## Packages to add (pubspec.yaml)

| Package | Purpose | Notes |
|---|---|---|
| `package_info_plus` | F-01 version display | |
| `flutter_map` | F-02 embedded map | OpenStreetMap, no API key |
| `latlong2` | F-02 coordinate type for flutter_map | |
| `flutter_map_cancellable_tile_provider` | F-02 efficient tile loading | |
| `geocoding` | F-02 reverse geocode pin position → address | |
| `geolocator` | F-02 device GPS for map default | Already in pubspec |
| `url_launcher` | F-02 open native maps app | Already in pubspec |
