# E2E UI tests (Appium + UiAutomator2)

Black-box UI tests that drive the **installed APK** on an Android emulator/device.
The harness is pure JavaScript (WebdriverIO + Appium) with **no Flutter
dependency** — it locates elements through the Android accessibility tree
(`resource-id` / `content-desc`), which the app populates via Flutter `Semantics`
(see `lib/a11y_ids.dart`).

## Prerequisites

- Node 20+ and npm
- An Android emulator or device, **API ≥ 30**, **x86_64** (matches `make debug`)
- A debug APK for that ABI — from the repo root:
  ```bash
  make debug   # -> build/app/outputs/flutter-apk/app-debug.apk  (needs JDK 17)
  ```

## Run locally

```bash
cd e2e
npm install
npm run driver:install        # installs uiautomator2@4.2.9 into ./.appium

npm run appium                # terminal 1: start the Appium server
npm test                      # terminal 2: emulator booted + apk built
```

Test a different build with `APP_PATH=/abs/path/to.apk npm test`.

## Specs

- `specs/home_happy_path.e2e.js` — launch + core navigation (location/theme sheets).
- `specs/accessibility.e2e.js` — black-box ADA: every control exposes a
  `content-desc` and is ≥ 48dp. Inline attribution links are size-exempt
  (WCAG 2.5.8 inline-text exception). Contrast is **not** covered black-box (deferred).

## Notes

- **Driver pin:** `uiautomator2@4.2.9` is the last driver compatible with Appium
  2.x (5.x+ require Appium 3). Bump both together.
- **Charts** are plain Flutter `Image` widgets (PNG rasterized natively), so a
  normal `Semantics` reaches them: they carry both a `resource-id`
  (`homeHourlyChart` / `homeWeeklyChart`) and a localized `content-desc` label
  (`descriptionContains("48-hour")` / `"7-day"`). Locate by either.
- Flutter text surfaces as `content-desc`, not the `text` attribute — locate by
  `resourceId` or `description*`, never `.text()`.
- CI: `.github/workflows/e2e.yml` (PR + manual) builds the x86_64 APK then runs
  these specs on a KVM-accelerated emulator.
