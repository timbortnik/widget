# Android Release Signing Setup

This document describes how to set up release signing for the Meteograph app.

## Overview

Google Play uses a two-key system:
- **Upload Key** - You create and manage this. Used to sign AABs before upload.
- **App Signing Key** - Google manages this. Signs the final APKs delivered to users.

If you lose your upload key, you can request a reset from Google (you still need to prove account ownership).

## Recommended Approach

**Storage:** Outside repo at `~/.android/keystores/meteogram-upload.jks`
**Backup:** Encrypted with GPG, stored in Google Drive
**Password:** One strong password for both keystore and encryption, written on paper at home

## Setup Steps

### 1. Create Keystore Directory

```bash
mkdir -p ~/.android/keystores
```

### 2. Generate Upload Keystore

```bash
keytool -genkey -v \
  -keystore ~/.android/keystores/meteogram-upload.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

You'll be prompted for:
- **Keystore password** - Use a strong password you'll remember
- **Key password** - Use the same password (press Enter to use keystore password)
- **Name, Organization, etc.** - Can use your real info or "Meteograph"

### 3. Create Encrypted Backup

```bash
cd ~/.android/keystores
gpg -c meteogram-upload.jks
# Enter the SAME password as the keystore
```

This creates `meteogram-upload.jks.gpg`

### 4. Upload Backup to Google Drive

Upload `meteogram-upload.jks.gpg` to your personal Google Drive.

### 5. Write Down Password

Write the password on paper. Store somewhere safe at home (not with your laptop).

### 6. Create key.properties

Create `android/key.properties` (already gitignored):

```properties
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=upload
storeFile=/home/YOUR_USERNAME/.android/keystores/meteogram-upload.jks
```

### 7. Update build.gradle.kts

The `android/app/build.gradle.kts` needs to be updated to read the signing config:

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.bortnik.meteogram"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

## Building Release

Once configured:

```bash
# Build release AAB (for Play Store)
flutter build appbundle --release

# Build release APK (for direct distribution)
flutter build apk --release
```

## Recovery Scenarios

| Scenario | Solution |
|----------|----------|
| Laptop dies | Download `.gpg` from Google Drive, decrypt with `gpg -d meteogram-upload.jks.gpg > meteogram-upload.jks` |
| Forgot password | Request upload key reset from Google Play Console (takes several days, requires identity verification) |
| Keystore corrupted | Restore from Google Drive backup |

## Security Notes

- `key.properties` is in `.gitignore` - never commit it
- `*.jks` and `*.keystore` are in `.gitignore` - never commit them
- The encrypted `.gpg` file is safe to store in cloud storage
- Use a strong password (12+ characters, mixed case, numbers, symbols)

## References

- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
