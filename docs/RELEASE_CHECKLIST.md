# Release Checklist for Meteogram Widget

This document tracks the status of all items needed for public release on Google Play Store.

## Status Overview

| Item | Status | Notes |
|------|--------|-------|
| Privacy Policy | ✅ DONE | `PRIVACY_POLICY.md` in repo root |
| Open-Meteo Attribution | ✅ DONE | Link in app UI (`home_screen.dart:686`) |
| README | ✅ DONE | `README.md` in repo root |
| App Icon | ✅ DONE | Adaptive icon in `res/drawable/ic_launcher_*.xml` |
| ProGuard/R8 | ✅ DONE | Configured in `build.gradle.kts`, 73% size reduction |
| Release Signing | ⏳ PENDING | Documented in `docs/RELEASE_SIGNING.md` |
| Store Listing Assets | ⏳ PENDING | Screenshots, feature graphic, description |

## Completed Items

### Privacy Policy
- **File:** `/PRIVACY_POLICY.md`
- **Covers:** Location data, local storage, Open-Meteo API, no tracking/analytics
- **TODO for release:** Host at a public URL (GitHub Pages or website)

### Open-Meteo Attribution
- **Location:** `lib/screens/home_screen.dart` line 686
- **Text:** "Weather data by Open-Meteo.com" with clickable link
- **Meets:** Open-Meteo API terms of service

### App Icon
- **Type:** Android Adaptive Icon (vector drawables)
- **Files:**
  - `android/app/src/main/res/drawable/ic_launcher_foreground.xml` - Stylized "M" temperature graph line
  - `android/app/src/main/res/drawable/ic_launcher_background.xml` - Purple background (#6750A4)
  - `android/app/src/main/res/drawable/ic_launcher_monochrome.xml` - Material You themed version
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` - Adaptive icon config
- **Note:** Fallback PNGs in mipmap folders are placeholders (only affects Android 7 and below)

### ProGuard/R8
- **Config file:** `android/app/proguard-rules.pro`
- **Build config:** `android/app/build.gradle.kts` lines 39-45
- **Size reduction:** 189MB (debug) → 50MB (release) = 73% smaller
- **Keep rules for:** Flutter, AndroidSVG, widget classes, platform views

## Pending Items

### Release Signing
- **Documentation:** `docs/RELEASE_SIGNING.md`
- **Status:** Documented but not implemented
- **Approach:**
  - Store keystore at `~/.android/keystores/meteogram-upload.jks`
  - Encrypt backup with GPG, store in Google Drive
  - Single password for keystore and encryption

#### Steps to Complete (for Claude):
1. User generates keystore with `keytool` command from docs
2. User creates encrypted backup and stores in Google Drive
3. User creates `android/key.properties` with credentials
4. Claude updates `android/app/build.gradle.kts` to read signing config

#### Changes needed in build.gradle.kts:
```kotlin
// ADD at top of file:
import java.util.Properties
import java.io.FileInputStream

// ADD after plugins block:
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ADD inside android block, before buildTypes:
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}

// CHANGE in buildTypes.release:
signingConfig = signingConfigs.getByName("release")
// (remove the debug signing config line)
```

### Store Listing Assets
- **Screenshots needed:**
  - Phone screenshots (at least 2, recommended 4-8)
  - Tablet screenshots (optional but recommended)
  - Widget on home screen
  - App main screen
  - Location search
  - Different weather conditions
- **Feature graphic:** 1024x500 PNG
- **Short description:** Max 80 characters
- **Full description:** Max 4000 characters
- **Category:** Weather
- **Content rating:** Complete questionnaire in Play Console

## Build Commands

```bash
# Debug build
flutter build apk --debug

# Release build (after signing is configured)
flutter build appbundle --release  # For Play Store (AAB)
flutter build apk --release        # For direct distribution (APK)

# Run tests
flutter test

# Check coverage
flutter test --coverage

# Analyze code
flutter analyze
```

## File Locations Summary

| Purpose | Location |
|---------|----------|
| Privacy Policy | `/PRIVACY_POLICY.md` |
| Release Signing Docs | `/docs/RELEASE_SIGNING.md` |
| This Checklist | `/docs/RELEASE_CHECKLIST.md` |
| ProGuard Rules | `/android/app/proguard-rules.pro` |
| App Icon (foreground) | `/android/app/src/main/res/drawable/ic_launcher_foreground.xml` |
| App Icon (background) | `/android/app/src/main/res/drawable/ic_launcher_background.xml` |
| Build Config | `/android/app/build.gradle.kts` |
| Key Properties | `/android/key.properties` (gitignored, user creates) |
| Keystore | `~/.android/keystores/meteogram-upload.jks` (outside repo) |
