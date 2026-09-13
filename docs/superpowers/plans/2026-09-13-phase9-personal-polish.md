# Phase 9: Personal-Use Polish Implementation Plan

> **For agentic workers:** This is the FINAL phase — it makes the app actually usable day-to-day on the author's own iPhone, not just feature-complete. Implement task-by-task, self-checking with `flutter test`/`flutter analyze` after each. No formal per-task review gate, but this phase has less domain-logic risk and more "does it actually work" risk than Phases 5-8 — be more careful about manual/visual verification where automated tests can't cover it (icon rendering, splash screen, real device build). Log anything uncertain or deferred to `docs/superpowers/ISSUES.md` under a new "Phase 9" section. **Do NOT run `firebase deploy`, do NOT attempt to code-sign or install onto a physical device, do NOT touch git branches beyond committing to the current one.**

**Goal:** Turn the 8-phase feature set into one coherent app: a real dashboard (not just a stacked list of cards with no shell), a profile/settings screen (sign out, adherence-weight configuration, app version, non-medical disclaimers in one place), a proper app icon and splash screen replacing Flutter defaults, Crashlytics wired in, and a clean release build. No monetization, no App Store submission — this app runs only on the author's own device.

**Spec:** `docs/ROADMAP.md` Phase 9 line; `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md` for cross-feature context (no new domain spec needed — this phase is integration/UI/build, not new domain logic).

## Current state (verified before writing this plan)

- `lib/features/dashboard/presentation/dashboard_screen.dart` is a single `SingleChildScrollView` of `GlassCard`s, one per feature (nutrition, workouts, body composition, goals, habits, adherence, readiness, coach, meal planning) — each just a description + a button that pushes a route. No app bar, no way to sign out, no settings entry point anywhere in the app.
- No `lib/features/settings/` or `lib/features/profile/` directory exists.
- `AdherenceWeights` (from Phase 5) has a repository (`users/{uid}/meta/adherenceWeights`) but **no UI to view or edit it** — users are stuck with the hardcoded defaults.
- `AuthRepository.signOut` exists but nothing in the UI calls it.
- App icon is still the default Flutter icon (`android/app/src/main/res/mipmap-*/ic_launcher.png` are stock); no `flutter_launcher_icons` or `flutter_native_splash` dependency in `pubspec.yaml`.
- No `firebase_crashlytics` dependency; no crash reporting wired into `main.dart`.
- No image-editing tool is installed (no ImageMagick, no Python Pillow). `python3` is available — installing Pillow via `pip install pillow` (or `python3 -m pip install --user pillow`) to programmatically generate a simple icon/splash PNG is acceptable; this is a one-time local build-tool install, not a runtime app dependency.

## Global Constraints

- Do not restructure existing feature routes or repositories — this phase adds a dashboard shell, a settings feature, icon/splash assets, and Crashlytics wiring around what exists.
- Follow existing visual conventions: dark near-black base, neon-glow accents, `GlassCard`/`PrimaryButton`/`AppColors`/`AppTypography` from `lib/core/` — never raw Material widgets or hardcoded colors for CTAs/accents.
- The app icon and splash screen must visually match this theme (dark background, a neon accent color from `AppColors`, simple/legible at small sizes — a small glyph or monogram, not a photo). Generate a simple, original icon programmatically (e.g. a rounded shape with a glow/gradient in the app's accent color, or a simple monogram) — do not use any third-party logo or copyrighted asset.
- Crashlytics must not block app startup if initialization fails (wrap in try/catch, same defensive pattern likely already used for other Firebase init in `main.dart` — check first).
- A release build means: `flutter build ios --release --no-codesign` and `flutter build apk --release` both complete without errors (proves the app compiles cleanly in release mode with tree-shaking/obfuscation-safe code). Actually installing onto the author's physical iPhone requires Xcode device pairing and Apple ID code-signing that this agent cannot perform — document the exact manual steps required (which Xcode menu, which settings) in `docs/superpowers/ISSUES.md` and/or a short section in `docs/ROADMAP.md`, but do not attempt them.
- Do not add Crashlytics/Analytics consent dialogs, tracking prompts, or anything App-Store-compliance-flavored — this is a private, single-user, non-distributed app; skip anything that only matters for public distribution.

## File Structure

- `lib/features/settings/presentation/settings_screen.dart` - profile info (email from `FirebaseAuth`), sign-out button, adherence weight sliders/inputs (reads/writes via the existing `AdherenceWeights` repository), app version (from `PackageInfo` or a hardcoded constant matching `pubspec.yaml`'s `version:`), and a short "not medical advice" disclaimer footer covering nutrition/readiness/body-composition estimates in one place.
- `lib/features/dashboard/presentation/dashboard_screen.dart` - add a top app bar with a settings icon button routing to `/settings`; consider light reorganization (e.g. section headers grouping Nutrition/Training vs. Habits/Readiness/Adherence vs. Goals/Coach/Meal Planning) if it's a small, low-risk change — skip reorganization if it risks breaking existing widget tests for this screen and just add the app bar entry point instead.
- `lib/core/router/app_router.dart` - add `/settings` route.
- `pubspec.yaml` - add `flutter_launcher_icons`, `flutter_native_splash`, `firebase_crashlytics`, `package_info_plus` (for version display) as dependencies/dev_dependencies as appropriate; add their config blocks.
- `assets/icon/icon.png` (new) - generated app icon source image (e.g. 1024x1024) used by `flutter_launcher_icons`.
- `assets/splash/splash.png` (new, if needed) - splash source image used by `flutter_native_splash`, or a solid-color + logo config if that package supports it without a raster asset.
- `lib/main.dart` - initialize Crashlytics (`FlutterError.onError` and `PlatformDispatcher.instance.onError` forwarding to `FirebaseCrashlytics.instance`), guarded so failure to init doesn't crash startup.
- `docs/superpowers/ISSUES.md` - Phase 9 section.
- `docs/ROADMAP.md` - mark Phase 9 done, with a clear note on the manual device-install/deploy steps still required.

## Tasks

1. **Settings screen — adherence weights UI.** Build the UI to view/edit the four `AdherenceWeights` components (nutrition/training/habits/recovery), validating they're non-negative and sum sensibly (reuse whatever validation convention `AdherenceWeights`/`AdherenceRepository` already has, if any — check before inventing new validation). Widget test for load/edit/save.
2. **Settings screen — profile + sign out.** Show the signed-in email, a sign-out button wired to `AuthRepository.signOut`, and app version. Widget test for sign-out button invoking the repository call (mock the repository boundary).
3. **Settings screen — disclaimers.** One consolidated "these are estimates, not medical advice" footer section referencing nutrition targets, body composition, and readiness — check existing per-screen disclaimer copy in `lib/features/readiness/` and `lib/features/body_composition/` and don't contradict it, just centralize a summary.
4. **Wire settings into navigation.** Add `/settings` route and an app-bar entry point from the dashboard. Update/extend the dashboard's existing widget test if one exists (`test/features/dashboard/...`) rather than letting it silently start failing.
5. **App icon.** Generate a simple, original, on-theme icon PNG (script it — Python+Pillow is fine to install locally for this one-time asset generation), add `flutter_launcher_icons` config to `pubspec.yaml`, run the icon generator, and verify `android/app/src/main/res/mipmap-*/ic_launcher.png` and the iOS `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` files actually changed from the Flutter defaults (diff file sizes/hashes before and after, don't just trust the tool ran).
6. **Splash screen.** Add `flutter_native_splash` config (dark background matching `AppColors`, the same icon or a simple wordmark), run its generator, verify native splash assets changed on both platforms.
7. **Crashlytics.** Add `firebase_crashlytics`, wire `main.dart` error forwarding guarded by try/catch, and confirm the app still boots (`flutter test` covering `main.dart`'s testable surface, plus a manual reasoning check — Crashlytics initialization must never be allowed to throw past its own try/catch and crash startup).
8. **Release build verification.** Run `flutter build apk --release` and `flutter build ios --release --no-codesign` and confirm both succeed with no errors (warnings about missing signing identity for iOS are expected and fine — that's the manual step). If either build fails for a reason unrelated to code-signing, fix it; if it's purely a signing/provisioning issue, log the exact error and required manual step to ISSUES.md.
9. **Regression pass.** Full `flutter test` + `flutter analyze` across the whole app (not just new files). Fix regressions; log anything non-obvious to ISSUES.md under "Phase 9".
10. **Document the manual finish line.** In `docs/ROADMAP.md`, add a short, clear "to actually run this on your phone" section: (a) `firebase deploy --only functions,firestore:rules` for Phases 7-8's backend pieces, (b) open `ios/Runner.xcworkspace` in Xcode, select a personal-team signing certificate and the physical device, and run in Release configuration (or use `flutter run --release -d <device-id>` once the device trusts the Mac and signing is set up). Be concrete and step-shaped, not vague.
11. **Commit.** `git add` specific relevant files (check `git status` first — new asset files, pubspec, generated icon/splash files across `android/`, `ios/`, `macos/` if `flutter_native_splash`/`flutter_launcher_icons` touch them), clear commit message, no push, no deploy, no device install attempt.
