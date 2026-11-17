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
| Remote content | The welcome popup is **static, built into the app**. There is no "other apps" image. The share text uses the iOS store link. The announcement popup comes from an **iOS-only** Firestore document with the same structure as Android's |
| Suggestions and contact | **No in-app suggestion form** (owner's decision, 2026-11-17). More → "Suggest an idea" opens the website's suggestions page (`/suggestions/`, in the app's language), where people write ideas and vote. More → "Contact us" opens an email to masebha0@gmail.com (the address itself is not shown). The app itself sends no data |
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
| **2: Supporter and data** | Purchases, the Support screen, the premium screen, feature gating, privacy policy, Wird, backup and restore (Android-compatible), TestFlight (needs the $99 account), and the Leap 1 review follow-ups below |
| **3: Online and release** | iOS announcement popup (Firestore REST), static welcome popup, promos, rating and sharing, the App Store listing, a full regression pass, and submission. (Suggestions are a website link, done in Leap 2.) |

## Leap 2: follow-ups from the Leap 1 review (owner's requests)

### 1. Long dhikr: one layout, no setting

**Remove the "Scroll long dhikr" setting.**
- The counter always follows the rule below.
- The stored key `scrollable_text` is no longer read or shown. An Android backup that contains it imports fine; the value is ignored.

**Layout rule: the dhikr text has priority over the ring size.**

Terms:
- `H` is the height between the toolbar and the previous/next bar.
- `S` is the statistics block (one or two rows).
- `P` is the fixed paddings.
- `Rmax` is the biggest ring: 340 pt, less on narrow screens.
- `Rmin` is the smallest ring: 240 pt.
- `Tn` is the text height at the user's font size, and `Ts` the text height at the small size (16 pt). Both are measured with the user's font.

The steps:
1. **Normal text.** If `Tn + S + P + Rmax ≤ H`: full text at the user's size, biggest ring, no scrolling. This is today's look for normal adhkar.
2. **Long text.** Otherwise, if `Tn + S + P + Rmin ≤ H`: full text at the user's size, no scrolling. The ring shrinks to fit exactly: `ring = H − Tn − S − P`, which stays between `Rmin` and `Rmax`.
3. **Very long text.** Otherwise:
   - The text switches to the small size. It never becomes larger than the user's own size.
   - `ring = clamp(H − Ts − S − P, Rmin, Rmax)`.
   - The text window takes all the rest: `H − S − P − ring`. There is no 4-line limit; the window is as big as possible.
   - If the small text is still taller than its window, it scrolls inside the window.

What stays the same:
- Taps anywhere count, on the text too. A swipe on the text scrolls it and never counts.
- Very short screens (the 4.7" iPhone SE with the biggest font and the "today" row) keep today's exception: the ring may go under `Rmin`, so that at least one line of text stays visible.

What changes, and is expected:
- The ring size can differ from one dhikr to the next.
- It is recomputed when the font size or the "today" row changes.

Acceptance:
- Unit tests (`CounterLayoutTests`) for each step and each boundary between steps, on 4.7" SE, mini, iPhone 17 and Pro Max sizes. Each case runs with the default and the biggest font, with and without the "today" row.
- Screenshots of step 1 (a short dhikr), step 2 (a medium-long one) and step 3 (Ayat al-Kursi), each with the default and the biggest font. Arabic first, plus one English set.
- UI test: taps on the text count, and swipes on the text do not.

### 2. Counter ring without the gap (only if easy: it is one padding value)
- The filled center circle touches the inner edge of the ring. Today there is a gap of about 5 pt.
- The same applies to the small ring previews on the theme page.
- Acceptance: screenshots on a dark theme, a light theme and a supporter theme.

### 3. Selected tab in green
- The selected tab of Apple's tab bar is green instead of iOS blue. Unselected tabs keep iOS's own colors.
- The glass is light or dark depending on what is behind it, so the green has two shades: a darker green on light glass (around `#16803C`) and a brighter one on dark glass (around `#30D158`). iOS picks the shade.
  - If the screenshots show that iOS does not switch shades inside the tab bar, use a single green that is readable on both.
- Acceptance: the selected tab is readable in screenshots on every theme. The hardest case is the green theme, with green cards behind the bar.

## Decisions made in Leap 2

**Supporter status (the critical part).** StoreKit 2 is the only source; the device keeps a saved record (`SupporterRules`, `Entitlements`).
- A supporter is never removed by being offline, by an error, by a slow App Store or by unverified data: "no answer" always keeps the saved record.
- The one-time purchase ends only with a verified refund from Apple.
- The monthly support ends only when Apple reports it expired or revoked, with a verified date more than 3 days old (renewals can reach the device late). Billing retry and grace periods count as supporting.
- `Transaction.updates` is observed from launch. Every transaction is finished after it is recorded. "Ask to Buy" unlocks when approved. "Restore purchases" calls `AppStore.sync()`.
- Deliberately generous: a phone restored from an iCloud backup keeps the saved record, even if the Apple ID changed. It is a thank-you tier, so a wrong "yes" costs less than a wrong "no".
- Supporter status is never read from or written to a backup file.
- **Testing.** The rules are pure and fully unit-tested (`SupporterRulesTests`, `EntitlementsTests`). The end-to-end StoreKit tests (`StoreKitTests`, `SupportUITests`) are written but **turned off on CI**: there the local test store returns no products (iOS 26.4 and 26.5 simulators, signed app, current `.storekit` format), so they cannot run. Real purchases, refunds, restore and "Manage subscription" are checked by hand with the owner's Apple account (sandbox / TestFlight) before release.

**Privacy policy.** Published on the app's website (`masebha-website` repo, generated by `build.py`): `https://tasbeeh-app.pages.dev/privacy/` and `/en/privacy/`. It describes what the iPhone app really does today. It also describes the website's suggestions page that the app links to. **Any change in data handling (for example, Leap 3's remote announcement popup) must update this page and the App Store privacy answers before release.** App Store Connect → App Privacy: "Data Not Collected".

**Products.** `nafii.masebha.support.monthly` (auto-renewable, group "Supporter") and `nafii.masebha.support.once` (non-consumable). Prices are set in App Store Connect and shown live.
- **At launch only the monthly product is created** (owner's decision). The app asks for both and shows only the products the App Store returns, so the one-time option appears by itself, without an app update, if it is ever created and approved later. Its rules and tests stay in place. The Support screen shows the auto-renewal text, Apple's standard Terms of Use and the privacy policy link (required by Apple).

**Wird.**
- Same tables, rules and default texts as Android. `WirdDefaults.json` is generated from `WirdDefaultData.java`.
- Non-supporters see an explanation page in the Wird tab (Android shows a popup). The data is never touched when support ends.
- The session uses the same text-first layout, pill, power mode and previous/next bar as the counter.
- Session details (owner's review): the progress bar, the wird's name and the position ("1 / 23") are one block above the zikr, and the skip icon points left in Arabic.

**Backup (format 1, both directions).**
- Settings are written with Android's value types: list choices as text ("30"), the reminder time as numbers. Every imported value is checked; a wrong one is ignored.
- Import is a full replace in one database transaction, after the whole file is checked: on any problem nothing changes.
- The wird section is always imported (it stays locked until the user supports). It is exported only when the user has wird data, so an Android import never replaces that phone's wirds with an empty list.

**Long dhikr (owner's rule, follow-up 1).** With the small 16 pt size in step 3, even the 4.7" iPhone SE with the biggest font and the "today" row keeps the 240 pt ring. Only a small iPhone with Display Zoom can shrink it.

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
- **Apple's standard tab bar, with no colors forced on it** (owner's choice). iOS colors the bar and its icons by itself. On iOS 26 the glass picks dark or light icons from what is behind it. The selected tab uses iOS's default color.
  - Earlier builds forced the bar to "dark" from the toolbar color, which gave white icons on light glass.
  - Each tab remembers its screen (for example, More stays on Settings).
- **Taps on the dhikr text count**, unlike on Android. A swipe on a long text scrolls it and never counts.
- **The "+" button is always visible.** The list gets extra space at the bottom so it never hides the last card; Android hid it while scrolling.
- **Add/Edit is an iOS sheet with inline error messages**, instead of a dialog with toasts. The validation rules are the same.
- **Counter reset is an iOS action sheet** with "Reset" / "Reset all" / "Cancel".
- **A new tap sound**, synthesized by `scripts/sound/make_tap_sound.py`. The loop sound is Android's `dawra.wav`.
- **Hijri month names are copied from Java's output**, so both apps print the same text. A test compares the iOS dates with Java's for 2020–2035.
- **The reminder row shows the real iOS status**: off, the scheduled time, or notifications not allowed.

## Waiting on the owner

- Real Android backup files, to confirm the import with real data (a hand-made Android-format file is tested meanwhile).
- The two products in App Store Connect with the IDs above, and their prices (needs the $99 account).
- A sharper 1024 px app icon before release. The current icon is the 512 px Android asset, upscaled.
- The iOS Firestore document for the announcement popup (Leap 3).
