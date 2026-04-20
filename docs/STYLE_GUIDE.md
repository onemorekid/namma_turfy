# Namma Turfy — Design Style Guide

Source: mockup screenshots (5-screen flow: Login → Home → Venue → Payment → Confirmation)

---

## 1. Color Palette

### Primary
| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#35CA67` | CTAs, active nav, available badges, checkmarks, prices |
| `primaryDark` | `#1A7A40` | Confirmation screen background, pressed state |
| `primaryLight` | `#E8F8EE` | Chip backgrounds, light highlight tints |

### Neutrals
| Token | Hex | Usage |
|-------|-----|-------|
| `surface` | `#FFFFFF` | Screen backgrounds, cards |
| `surfaceVariant` | `#F5F5F5` | Input backgrounds, shimmer base |
| `onSurface` | `#1A1A1A` | Primary text |
| `onSurfaceVariant` | `#666666` | Secondary text, subtitles, captions |
| `outline` | `#E0E0E0` | Card borders, dividers |
| `outlineVariant` | `#BDBDBD` | Input borders |

### Semantic
| Token | Hex | Usage |
|-------|-----|-------|
| `peakTime` | `#FF6B35` | Peak-time slot badge, peak price text |
| `peakTimeBg` | `#FFF0EA` | Peak-time slot row background tint |
| `offer` | `#FF8C00` | Offer/promo banner background |
| `offerBg` | `#FFF3DC` | Offer banner background (light) |
| `star` | `#FFC107` | Star rating fill |
| `error` | `#E53935` | Error messages, unavailable X icon |
| `errorBg` | `#FFEBEE` | Error/booked slot row tint |

### Dart constants (put in `lib/core/theme/app_colors.dart`)
```dart
class AppColors {
  // Primary
  static const primary        = Color(0xFF35CA67);
  static const primaryDark    = Color(0xFF1A7A40);
  static const primaryLight   = Color(0xFFE8F8EE);

  // Neutrals
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const onSurface      = Color(0xFF1A1A1A);
  static const onSurfaceVar   = Color(0xFF666666);
  static const outline        = Color(0xFFE0E0E0);
  static const outlineVariant = Color(0xFFBDBDBD);

  // Semantic
  static const peakTime       = Color(0xFFFF6B35);
  static const peakTimeBg     = Color(0xFFFFF0EA);
  static const offer          = Color(0xFFFF8C00);
  static const offerBg        = Color(0xFFFFF3DC);
  static const star           = Color(0xFFFFC107);
  static const error          = Color(0xFFE53935);
  static const errorBg        = Color(0xFFFFEBEE);
}
```

---

## 2. Typography

Font family: **Outfit** (already loaded via `google_fonts`)  
All sizes in logical pixels (sp).

| Style | Weight | Size | Usage |
|-------|--------|------|-------|
| `displayLarge` | Bold 700 | 32 | App name on splash/login |
| `headlineMedium` | Bold 700 | 24 | Screen titles (Booking Confirmed!) |
| `titleLarge` | SemiBold 600 | 20 | App bar titles, card venue names |
| `titleMedium` | SemiBold 600 | 16 | Section headers ("Popular Turfs") |
| `bodyLarge` | Regular 400 | 16 | Slot times, primary body |
| `bodyMedium` | Regular 400 | 14 | Secondary body, descriptions |
| `bodySmall` | Regular 400 | 12 | Captions, distance labels, reviews count |
| `labelLarge` | Bold 700 | 16 | Button text |
| `labelMedium` | SemiBold 600 | 14 | Badge/chip text |
| `labelSmall` | Medium 500 | 11 | Bottom nav labels |

### Price text
Always use `Bold 700` + `AppColors.onSurface` for regular prices.  
Use `Bold 700` + `AppColors.peakTime` for peak-time prices.  
Use `Bold 700` + `AppColors.primary` for totals / CTAs.

---

## 3. Spacing & Layout

```
Base unit: 4px
xs:   4px
sm:   8px
md:  16px   ← standard horizontal screen padding
lg:  24px   ← section vertical spacing
xl:  32px
xxl: 48px
```

- **Screen horizontal padding:** 16px on all content screens
- **Card internal padding:** 12–16px
- **Between list items:** 12px
- **Between section header and content:** 8px
- **Bottom CTA button bottom padding:** 20px + SafeArea

---

## 4. Elevation & Shadows

The mockup uses **flat design with border shadows**, no Material elevation:

```dart
// Standard card shadow (used on turf cards, booking cards)
BoxShadow(
  color: Color(0x0D000000),   // 5% black
  blurRadius: 8,
  offset: Offset(0, 2),
)

// Floating CTA bar (bottom payment bar)
BoxShadow(
  color: Color(0x14000000),   // 8% black
  blurRadius: 12,
  offset: Offset(0, -4),
)
```

Cards have `elevation: 0` with a `1px #E0E0E0` border (already set in `main.dart`).

---

## 5. Border Radius

| Component | Radius |
|-----------|--------|
| Buttons (full-width CTA) | `12px` |
| Cards | `16px` |
| Chips / badges | `20px` (pill) |
| Slot row | `10px` |
| Venue hero image | `16px` (bottom corners on top of screen) |
| Avatar / venue thumbnail | `10px` |
| Input fields | `10px` |
| Bottom sheet | `20px` (top corners) |
| Offer banner | `12px` |

---

## 6. Components

### 6.1 Buttons

#### Primary CTA (full-width, green)
```
Height:      56px
Width:       fill (minus 16px each side)
Radius:      12px
Background:  AppColors.primary
Text:        labelLarge, white
Padding:     horizontal 24px, vertical 16px
```
Example: "Proceed to Pay ₹800", "Confirm Booking", "LOGIN"

#### Secondary / Outline
```
Height:      56px
Background:  White
Border:      1.5px AppColors.outline
Text:        labelLarge, AppColors.onSurface
Radius:      12px
```
Example: "SIGN UP" on login screen

#### Text button
```
Text color:  AppColors.primary
Weight:      SemiBold 600
```
Example: "See all", "REGISTER NOW"

---

### 6.2 Slot Row
Displays an individual time slot on venue and payment screens.

```
Layout: Row — [time + price] | [badge]
Height: ~52px
Radius: 10px
Padding: 12px horizontal, 10px vertical
Border: 1px outline

States:
  Available   → background: white,           badge: green pill "Available",    right icon: green ✓
  Peak Time   → background: AppColors.peakTimeBg, badge: orange pill "Peak Time", right icon: red ✗, price color: peakTime
  Booked      → background: AppColors.surfaceVariant, badge: grey pill "Booked", text: greyed out
  Selected    → background: AppColors.primaryLight, border: 2px AppColors.primary
```

Badge pill:
```
Padding: 6px horizontal, 3px vertical
Radius: 20px (pill)
Text: labelSmall, white
```

---

### 6.3 Venue / Turf Card (Home list)
```
Layout: Row — [120×80 thumbnail] | [Name, stars, price, distance badge]
Radius: 16px
Background: white
Shadow: standard card shadow
Thumbnail radius: 10px (left-side corners)
Distance badge: dark pill, bodySmall white, position: top-left on thumbnail
Book Now badge: AppColors.primary pill, bottom-right corner of card
```

---

### 6.4 Star Rating
```
Filled star:   AppColors.star (#FFC107)
Empty star:    AppColors.outlineVariant
Size:          16px (list), 20px (detail screen)
Spacing:       2px between stars
Rating text:   bodyMedium bold, AppColors.onSurface
Reviews count: bodySmall, AppColors.onSurfaceVar  "( 120 Reviews )"
```

---

### 6.5 Offer / Promo Banner
```
Background:  AppColors.offerBg
Border:      1px AppColors.offer
Radius:      12px
Padding:     12px horizontal, 10px vertical
Icon:        Offer/tag icon, AppColors.offer
Title:       titleMedium, AppColors.offer  "Offers Available!"
Subtitle:    bodyMedium, AppColors.onSurface  "50% OFF Selected Slots"
Dismiss:     X icon, AppColors.onSurfaceVar, top-right
```

---

### 6.6 Bottom Navigation Bar
```
Height: 60px + SafeArea
Background: white
Shadow: floating CTA bar shadow (inverted — top shadow)
Items: 4 — Home, Bookings, Tournaments, Profile
Active icon + label: AppColors.primary
Inactive icon: AppColors.outlineVariant
Active label: labelSmall, AppColors.primary, SemiBold
Inactive label: labelSmall, AppColors.onSurfaceVar
```

---

### 6.7 Confirmation Screen
```
Background: AppColors.primaryDark  (#1A7A40 or deep green)
Title: displayLarge, white, centered
Subtitle: headlineMedium, white

Success checkmark:
  Outer circle: white, diameter 80px
  Inner icon: ✓ green, 40px

Booking summary card:
  Background: white, radius 16px, padding 16px
  Contains: thumbnail, venue name, stars, time/date, booking ID

Action buttons (VIEW BOOKING, SHARE DETAILS):
  Side-by-side, 50% width each
  Background: AppColors.primary
  Text: white, labelMedium

Tournament banner at bottom:
  Dark card with image, "REGISTER NOW" green button
```

---

### 6.8 Login / Splash Screen
```
Background: full-bleed stadium image + dark overlay (opacity 0.55)
Logo:       football icon (white outline, 80px)
App name:   displayLarge, white, bold, centered
Tagline:    bodyLarge, white 70% opacity

Buttons: stacked vertically, 16px gap
  Login:   primary green filled
  Sign up: white outlined (white border, white text)
```

---

### 6.9 Date / Day Selector (Venue Screen)
```
Layout: horizontal scroll, 7 columns
Each cell:
  Day label: bodySmall, AppColors.onSurfaceVar
  Date number: titleMedium, AppColors.onSurface
  Selected state: circle background AppColors.primary, text white
  Today: underline or dot in AppColors.primary
Cell size: 40×48px
```

---

### 6.10 App Bar
```
Background: white
Title: titleLarge, AppColors.onSurface, left-aligned
Elevation: 0 (no shadow — border-bottom 1px AppColors.outline)
Back icon: arrow_back_ios_new, AppColors.onSurface
Right icons: bell (notification), 24px, AppColors.onSurface
```

---

### 6.11 Location Picker
```
Layout: Row — [pin icon] [city name] [dropdown chevron]
Icon color: AppColors.primary
Text: titleMedium, AppColors.onSurface, SemiBold
Border: 1px AppColors.outline, radius 10px
Padding: 10px horizontal, 8px vertical
Background: AppColors.surfaceVariant
```

---

## 7. Iconography

| Context | Icon | Source |
|---------|------|--------|
| Location | `Icons.location_on` | Material |
| Distance | `Icons.near_me` or `Icons.directions_walk` | Material |
| Star rating | `Icons.star` / `Icons.star_border` | Material |
| Available checkmark | `Icons.check_circle` | Material |
| Unavailable X | `Icons.cancel` | Material |
| Bell / notifications | `Icons.notifications_none` | Material |
| Filter | `Icons.tune` or `Icons.filter_list` | Material |
| Home | `Icons.home_outlined` | Material |
| Bookings | `Icons.calendar_today_outlined` | Material |
| Tournaments | `Icons.emoji_events_outlined` | Material |
| Profile | `Icons.person_outline` | Material |
| Peak time | `Icons.bolt` (lightning) | Material |
| Share | `Icons.ios_share` | Material |
| Back | `Icons.arrow_back_ios_new` | Material |

Icon size: 24px default, 20px in dense contexts, 28px for bottom nav

---

## 8. Imagery

- Venue hero images: aspect ratio **16:9**, `BoxFit.cover`, radius on shown corners
- Venue thumbnail in list: **120×80px**, radius 10px, `BoxFit.cover`
- Venue thumbnail in summary: **60×60px**, radius 8px, `BoxFit.cover`
- Always use a placeholder/shimmer while loading (grey #E0E0E0 fill)
- Broken image fallback: `Icons.sports_soccer` (green, centered)

---

## 9. Motion & Transitions

| Interaction | Duration | Curve |
|-------------|----------|-------|
| Page push/pop | 300ms | `Curves.easeInOut` |
| Bottom sheet open | 250ms | `Curves.easeOut` |
| Slot tap → selected | 150ms | `Curves.easeIn` |
| Offer banner dismiss | 200ms | `Curves.easeOut` |
| Button press feedback | 100ms | `Curves.easeIn` |
| Snackbar slide-up | 200ms | `Curves.easeOut` |

---

## 10. Implementation Checklist

- [ ] Create `lib/core/theme/app_colors.dart` with all color constants
- [ ] Create `lib/core/theme/app_text_styles.dart` with named text styles
- [ ] Create `lib/core/theme/app_theme.dart` with full `ThemeData` (migrate from `main.dart`)
- [ ] Create `lib/core/theme/app_spacing.dart` with spacing constants
- [ ] Build `SlotRowWidget` reusable component (available / peak / booked / selected states)
- [ ] Build `VenueCard` reusable component (list card used on home screen)
- [ ] Build `StarRatingWidget` reusable component
- [ ] Build `OfferBanner` reusable component
- [ ] Update `LoginScreen` to match splash/login mockup (hero image + overlay)
- [ ] Update `HomeScreen` with bottom nav, location picker, "Popular Turfs" layout
- [ ] Update `VenueDetailsScreen` with day-selector + new slot row component
- [ ] Update `CheckoutScreen` ("Payment Summary" layout from mockup)
- [ ] Update `ReceiptScreen` (dark green confirmation screen from mockup)
- [ ] Replace hardcoded colors across all screens with `AppColors.*` tokens

---

## 11. Gaps vs Current App

| Mockup Element | Current App Status |
|----------------|--------------------|
| Bottom navigation bar (Home/Bookings/Tournaments/Profile) | Missing — uses Drawer |
| Location picker on home screen | Missing |
| Offer/promo banner on home screen | Missing |
| Slot rows with colour-coded states (peak/available/booked) | Partial |
| Star ratings on cards | Missing |
| Distance labels | Missing |
| Dark green confirmation screen | Plain white receipt screen |
| Day/date selector on venue screen | Missing — uses date picker |
| Venue card with Book Now badge + distance chip | Basic list tile |
| Tournament section on confirmation screen | Missing (intentionally disabled) |
| Login with full-bleed stadium image + overlay | Basic white login screen |
