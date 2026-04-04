## Project Overview
This document serves as the implementation roadmap for "Namma Turfy", a sports ground booking app. The AI agent must follow this phased approach strictly, completing all validation steps and automated quality gates (using `/commit` to run `dart format`, `dart analyze`, and `flutter test`) before moving to the next phase.

### Core Agent Directives
*   **Target Platforms:** Android and Web ONLY.

---

## Phase 1: Core User, Booking & Payments MVP
**Goal:** Establish user onboarding, venue discovery, real-time booking, and checkout.

*   [x] **Step 1.1: Authentication (Google-Only)**
    *   Implement Firebase Authentication restricted entirely to Google Sign-In.
    *   **Constraint:** Do not ask for a phone number during the initial onboarding. The login flow must be frictionless.
*   [x] **Step 1.2: Deferred Profile Completion**
    *   Build a user profile management section where users enter their phone number *after* successful onboarding.
*   [x] **Step 1.3: Venue Discovery & Real-Time Booking**
    *   Implement a search and filtering system for venues based on location, date, and availability.
    *   Build a calendar-based booking system displaying real-time slot availability.
*   [x] **Step 1.4: Payment Gateway (Razorpay Only)**
    *   Integrate Razorpay as the exclusive payment gateway.

---

## Phase 2: Event Discovery
**Goal:** Allow users to find and participate in sports events.

*   [x] **Step 2.1: Event Discovery Board**
    *   Implement a dedicated section for users to discover, promote, and participate in local sports tournaments and fitness events.
    *   **Constraint:** Restrict this phase *entirely* to event discovery.

---

## Phase 3: Facility Owner & Admin Portals
**Goal:** Provide management tools for venue owners and super-admins.

*   [x] **Step 3.1: Super-Admin Commission Engine**
    *   Build a financial module for the platform admin.
    *   **Constraint:** Enforce a tiered commission configuration. The admin must have a dropdown setting to apply a strict commission rate of **3%, 5%, or 8%** on a per-venue basis.
*   [x] **Step 3.2: Venue Management Dashboard**
    *   Develop an interface for facility owners to list their venues, upload images, and update slot availability.
    *   Build an earnings dashboard to track revenue *minus* the admin's configured 3%, 5%, or 8% commission.

---

## Phase 4: Advanced Features & Polish
**Goal:** Enhance user retention and application branding.

*   [x] **Step 4.1: Targeted Push Notifications**
    *   Integrate Firebase Cloud Messaging (FCM) to send real-time game updates and booking reminders.
*   [x] **Step 4.2: Venue Visualization**
    *   Implement high-quality image galleries or 360-degree virtual venue tours.
*   [x] **Step 4.3: App Branding (Android & Web Only)**
    *   **Android Icon:** Use `flutter_launcher_icons` to replace the `ic_launcher.png` files in the `android/app/src/main/res/mipmap-*` directories.
    *   **Android Splash Screen:** Modify `android/app/src/main/res/drawable/launch_background.xml` to center the app logo on the native splash screen.
    *   **Web Branding:** Update the `favicon.png` and icons inside the `web/icons/` directory.

---

## Phase 5: Android & Web Build Configurations
**Goal:** Prepare the application for production deployment.

*   [x] **Step 5.1: Web Optimization**
    *   Configure the web build to utilize WebAssembly (Wasm) for maximum execution speed. The agent must use the build command `flutter build web --wasm`.
*   [x] **Step 5.2: Android Code Signing & AAB Generation**
    *   Create an upload keystore and configure `android/key.properties`.
    *   Modify `android/app/build.gradle` to include `signingConfigs`. 
    *   Generate the production-ready Android App Bundle using `flutter build appbundle`.

---

## Agent Verification Protocol
After completing each phase, the agent MUST:
1. Run `flutter test` to ensure Red-Green-Refactor TDD loops are satisfied.
2. Execute `dart format .` and `dart fix --apply`.
3. Run `dart analyze` to catch any static validation issues.
4. Update this `IMPLEMENTATION.md` file to check off completed steps.
5. Use the `/commit` command to automatically generate a meaningful, semantic commit message and commit the changes.
6. Execute `git push` to push the changes to the remote repository.