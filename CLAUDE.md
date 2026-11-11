# CLAUDE.md: Masebha iOS

Native iOS port of the Android tasbih app **Masebha** (store name *Tasbeeh*). Bundle ID `nafii.masebha`.

Product decisions and roadmap: [`docs/plan.md`](docs/plan.md). Read it before starting work.

## Non-negotiables

- **Reliability and data integrity come first.** Real users will install this, including paying supporters and people migrating from Android. No shortcuts in persistence, lifecycle, notifications, or purchases.
- **The owner does not read Swift.** They validate by testing.
  - Explain decisions briefly, in Android terms.
  - After each leap, give exact manual test steps, including edge cases.
- **Keep it simple.** The owner hates overcomplexity. Prefer the simplest robust solution and avoid new dependencies.
- **Never modify the Android project** at `C:\Users\abouh\OneDrive\Desktop\Masebha`. It is the read-only reference: its `AGENTS.md` and its `docs/` (`architecture.md`, `data-model.md`, `known-issues.md`, `features/01–13`).
- **If an Android feature does not map cleanly to iOS, stop and discuss it with the owner.** That covers platform limits, Apple policy, fragile imitations, and cases with a better native option. Never silently drop or compromise a feature.
- **A green build is not proof.**
  - Unit-test business logic, persistence, and purchases.
  - Run CI after every significant change.
  - Look at the UI-test screenshots.

## Build and test (there is no Mac)

Development happens on Windows, and nothing compiles locally. Every build runs on GitHub Actions: [`.github/workflows/ios.yml`](.github/workflows/ios.yml), using `macos-26` and the newest stable Xcode 26.

- `project.yml` (XcodeGen, pinned to 2.46.0) defines the project. The `.xcodeproj` is generated on CI. Never commit it or edit it.
- **Each push to `main`:**
  1. generates the project;
  2. runs unit and UI tests in the Simulator;
  3. exports screenshots;
  4. builds an unsigned `Masebha-dev.ipa` with bundle ID `nafii.masebha.dev`.
- **Inspecting a run.** `gh` lives at `C:\Program Files\GitHub CLI\gh.exe` if it is not on PATH.
  - `gh run list`, `gh run watch <id>`
  - `gh run view <id> --log-failed`
  - `gh run download <id> -n test-results` (screenshots + summary)
  - `gh run download <id> -n Masebha-dev-ipa`
- **Installing on the owner's iPhone.**
  - Until purchases (Leap 2): Sideloadly and a free Apple ID. The build expires after 7 days.
  - From Leap 2: the paid developer account and TestFlight.
- **CI minutes.** The repo is public, so standard runners are free. If it goes private, it gets about 200 macOS minutes/month; batch changes then.
- Write Swift carefully. Compiler errors only show up in CI logs, and each round costs about 10 minutes.

## Architecture

```
SwiftUI Views                 screens (≈ Activity + layout)
@Observable models            screen state and logic (≈ ViewModel)
Stores                        all SQL (≈ CounterStore / WirdStore)
AppDatabase (GRDB)            SQLite with versioned migrations
Services                      Purchases (StoreKit 2), Reminders, Settings (UserDefaults), Backup, Remote
Pure logic                    counter math, wird day rules, backup codec; no UI, no DB, fully unit-tested
```

- The app entry point (`MasebhaApp`) creates the services once and passes them down. There is no DI framework.
- **Persist on every change, never "on exit".** iOS can kill a suspended app without any callback.

## Conventions

- **Concurrency.** Swift 6 with default actor isolation `MainActor`: everything runs on the main thread unless it is marked `nonisolated`.
- **Strings.**
  - String Catalogs (`Localizable.xcstrings`), with Arabic as the source language.
  - Semantic keys (`feature.thing`), each with both `ar` and `en` values.
  - Never hard-code UI text.
- **Digits** are ASCII everywhere, except the Hijri date in Arabic, which uses Arabic-Indic digits (as on Android).
- **Display scope:** light mode forced, portrait only, iPhone only, iOS 17+.
- **The repo is public: never commit secrets.** That means certificates, provisioning profiles, `.p8` keys, and `.env` files.
