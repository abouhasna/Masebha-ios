# Plan: decisions and roadmap

Agreed with the owner on 2026-11-11. The reference for Android behavior is the Android repo's `docs/`.

## Technology

| Need | Choice |
|---|---|
| UI | Swift 6 + SwiftUI, iOS 17+, iPhone only |
| Database | GRDB (SQLite) with versioned migrations |
| Settings | UserDefaults, behind one typed wrapper that lists every key and default in one place |
| Purchases | StoreKit 2 |
| Reminder | UserNotifications (a repeating calendar trigger) |
| Firestore | Plain HTTPS against the Firestore REST API (no Firebase SDK) |
| Project | XcodeGen (`project.yml`) |
| Tests | Swift Testing (unit), StoreKitTest (purchases), XCUITest (UI, with screenshots) |
| CI | GitHub Actions `macos-26` |

## Android → iOS decisions

| Area | Decision |
|---|---|
| Floating counter | **Not implemented on iOS.** iOS forbids drawing over other apps |
| Auto-timer | Runs only while the app is on screen; the screen is kept awake. Locking the phone or leaving the app **pauses** it; counts are already saved and ▶ resumes. A Dynamic Island display may come later (display only: iOS cannot tick or vibrate in the background) |
| Language | Chosen **in the app**: an unskippable picker on first launch, plus a Settings row. Native RTL or LTR follows the chosen language. Never rely on the iOS Settings per-app language |
| Navigation | Bottom tab bar instead of the drawer. Keep the floating **+** button. **Long-press on a card reorders**; card actions stay in the ⋮ menu |
| Supporter | Two products: one monthly subscription and one one-time purchase. Supporter status is yes/no, with no levels. Android supporters must support again on iOS (separate stores, no accounts) |
| Backup import | Format `format: 1`, compatible with Android in both directions. Wird data is **always** imported and stays locked until the user is a supporter (Android drops it) |
| Rating | Apple's system review prompt replaces the custom launch-7 popup. The menu's "Rate" item opens the App Store review page |
| Remote content | The welcome popup is **static, built into the app**. There is no "other apps" image. The share text uses the iOS store link. The announcement popup and the suggestions come from **iOS-only** Firestore documents with the same structure as Android's |
| Privacy policy | Written with the purchases work (required by Apple) |
| Sounds | Redesign the tap sound to feel native and premium. Sounds respect the Silent switch |
| Vibration | Core Haptics, keeping the same duration settings so backups stay compatible |
| Design | Small native tweaks are allowed where the Android design would feel cheap on iPhone. Keep the app identity and colors |
| Colors | Use the system color picker. Losing supporter status never overwrites saved colors (fixes Android D5) |
| Orientation | Portrait only for now. Android allows rotation |

## Data model improvements over Android

- Versioned migrations from day one.
- Foreign keys with cascade, so no orphan stats rows.
- Counts are saved as increments (`total = total + 1`), never as absolute totals (fixes D2).
- The first-run seed runs in one transaction (fixes R5).
- One date format everywhere.
- Supporter status comes only from StoreKit, never from a backup (S1 cannot happen).
- Remote content is validated, so a bad remote image cannot crash the app (R1).

## Roadmap (leaps)

Every leap ends with a CI build, automated tests, the owner's manual test checklist, and the owner's acceptance.

| Leap | Scope |
|---|---|
| **0: Pipeline** | Project skeleton, CI (build, tests, screenshots, unsigned IPA), sideload to the owner's iPhone |
| **1: Core app (free features)** | Database, the Azkar list (add, edit, delete, reorder, reset, seeds), counter (taps, loops, undo, resets, resume loop, daily stats, prev/next, sounds, haptics, power mode, coach mark), auto-timer and timer dialog, settings, themes and custom colors, fonts and font size (paid items behind a debug switch), language and RTL, Hijri date, daily reminder |
| **2: Supporter and data** | Purchases, the Support screen, the premium screen, feature gating, privacy policy, Wird, backup and restore (Android-compatible), TestFlight (needs the $99 account) |
| **3: Online and release** | iOS popup and suggestions (Firestore REST), static welcome popup, promos, rating and sharing, the App Store listing, a full regression pass, and submission |

## Implementation choices made in Leap 1

These are small differences from Android, decided during the build. Each one is reversible.

- **Native mirroring in Arabic.** Previous/Next, Total/Loops and the "+" button swap sides, as in native Arabic iOS apps. The ± buttons of the timer dialog stay left-to-right, because they show numbers.
- **"Sound while timer runs in background" is not on iOS.** iOS has no background timer (decision Q2).
- **Timer dialog "Cancel" discards the change.** On Android a cancelled change was kept by mistake.
- **Reordering.** Press and hold a card, then drag it, like Android. iOS lifts the card on every supported version (16+).
  - "⋮ → Reorder" opens a reorder mode: our own ≡ on every card (in the card's text color, so it shows on any theme, custom colors included), a hint, and "Done". Cards do not open while it is on.
  - iOS's built-in edit-mode handles are not used: they are always gray, cannot be colored, and vanish on mid-gray colors.
- **The Hijri date header is centered** in the title area (iOS style). iOS 26 wraps side items in a glass capsule that clipped the text.
- **iOS 26 look.** Toolbar buttons sit in the system's glass capsule. The theme colors still apply to the bars and screens.
- **Our own bottom bar, solid like Android's.** iOS 26's tab bar is see-through glass whose colors follow the content behind it, which made icons unreadable on some themes.
  - Colors as on Android: the toolbar color behind, the toolbar accent on it (switched to white or near-black if not readable). The unselected tab is faded to 70% (Android: 55%).
  - It shows on the tab screens and on Settings. It does not show on the counter screen.
  - Choosing a tab opens that tab's first screen.
- **Counter ring size.** It is at least 240 pt on every iPhone, with one exception: the 4.7" iPhone SE with the biggest font and the "today" row on. There the ring shrinks to about 208 pt, so that it never goes under the buttons.
- **Taps on the dhikr text count**, unlike on Android. A swipe scrolls the text (scroll mode) or the page (no scroll mode), and never counts.
- **The "+" button is always visible.** The list gets extra space at the bottom so it never hides the last card; Android hid it while scrolling.
- **Add/Edit is an iOS sheet with inline error messages**, instead of a dialog with toasts. The validation rules are the same.
- **Counter reset is an iOS action sheet** with "Reset" / "Reset all" / "Cancel".
- **A new tap sound**, synthesized by `scripts/sound/make_tap_sound.py`. The loop sound is Android's `dawra.wav`.
- **Hijri month names are copied from Java's output**, so both apps print the same text. A test compares the iOS dates with Java's for 2020–2035.
- **The reminder row shows the real iOS status**: off, the scheduled time, or notifications not allowed.

## Waiting on the owner

- Android backup files to use as test fixtures (needed in Leap 2).
- A sharper 1024 px app icon before release. The current icon is the 512 px Android asset, upscaled.
- The Firestore documents and collection for iOS (Leap 3).
