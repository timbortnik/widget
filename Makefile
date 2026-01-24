# Build targets for Meteograph

FLUTTER := ~/git/flutter/bin/flutter

# Version from git tag (e.g., v1.0.1 -> 1.0.1), fallback to 0.0.0
VERSION_NAME := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
# Build number from commit count (always incrementing)
VERSION_CODE := $(shell git rev-list --count HEAD)

.PHONY: debug release release-all release-split bundle install install-debug clean version test test-dart test-kotlin analyze

# Generate version.dart from git info (tag or commit hash)
version:
	@./scripts/generate_version.sh

# Debug build (x86_64 only for emulator)
debug: version
	$(FLUTTER) build apk --debug --target-platform android-x64

# Release build (arm64 only, ~19 MB)
release: version
	@echo "Building version $(VERSION_NAME)+$(VERSION_CODE)"
	$(FLUTTER) build apk --release --target-platform android-arm64 \
		--build-name=$(VERSION_NAME) --build-number=$(VERSION_CODE)

# Release build with all architectures (~52 MB)
release-all: version
	@echo "Building version $(VERSION_NAME)+$(VERSION_CODE)"
	$(FLUTTER) build apk --release \
		--build-name=$(VERSION_NAME) --build-number=$(VERSION_CODE)

# Split APKs by architecture (for manual distribution)
release-split: version
	@echo "Building version $(VERSION_NAME)+$(VERSION_CODE)"
	$(FLUTTER) build apk --release --split-per-abi \
		--build-name=$(VERSION_NAME) --build-number=$(VERSION_CODE)

# App Bundle for Play Store (Google optimizes delivery)
bundle: version
	@echo "Building version $(VERSION_NAME)+$(VERSION_CODE)"
	$(FLUTTER) build appbundle --release \
		--build-name=$(VERSION_NAME) --build-number=$(VERSION_CODE)

# Install release APK on connected device
install: release
	adb install -r build/app/outputs/flutter-apk/app-release.apk

# Install debug APK on connected device
install-debug: debug
	adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Clean build artifacts
clean:
	$(FLUTTER) clean

# Run all tests (Dart + Kotlin)
test: test-dart test-kotlin

# Run Dart/Flutter tests only
test-dart:
	$(FLUTTER) test

# Run Kotlin unit tests only (requires JDK 17+, set JAVA_HOME if needed)
test-kotlin:
	cd android && ./gradlew :app:test --console=plain

# Run Flutter analyzer
analyze:
	$(FLUTTER) analyze
