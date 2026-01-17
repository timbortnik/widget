# Build targets for Meteogram Widget

FLUTTER := ~/git/flutter/bin/flutter

.PHONY: debug release release-all release-split bundle install install-debug clean version

# Generate version.dart from git info (tag or commit hash)
version:
	@./scripts/generate_version.sh

# Debug build (x86_64 only for emulator)
debug: version
	$(FLUTTER) build apk --debug --target-platform android-x64

# Release build (arm64 only, ~19 MB)
release: version
	$(FLUTTER) build apk --release --target-platform android-arm64

# Release build with all architectures (~52 MB)
release-all: version
	$(FLUTTER) build apk --release

# Split APKs by architecture (for manual distribution)
release-split: version
	$(FLUTTER) build apk --release --split-per-abi

# App Bundle for Play Store (Google optimizes delivery)
bundle: version
	$(FLUTTER) build appbundle --release

# Install release APK on connected device
install: release
	adb install -r build/app/outputs/flutter-apk/app-release.apk

# Install debug APK on connected device
install-debug: debug
	adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Clean build artifacts
clean:
	$(FLUTTER) clean
