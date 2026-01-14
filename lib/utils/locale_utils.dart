import 'dart:io';
import 'package:flutter/material.dart';

/// Utilities for locale parsing and handling.
class LocaleUtils {
  /// Parse a locale string (e.g., "en_US", "en-US", "en") into a Locale.
  /// Returns Locale('en') if the input is empty or invalid.
  static Locale parseLocaleString(String localeStr) {
    if (localeStr.isEmpty) return const Locale('en');

    // Handle formats: "en", "en_US", "en-US", "en_US.UTF-8"
    final cleaned = localeStr.split('.').first; // Remove .UTF-8 suffix
    final parts = cleaned.split(RegExp(r'[_-]')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty || parts[0].isEmpty) return const Locale('en');

    if (parts.length >= 2) {
      return Locale(parts[0], parts[1].toUpperCase());
    }
    return Locale(parts[0]);
  }

  /// Get current system locale from Platform.localeName.
  /// Returns Locale with language and country code (e.g., en_US -> Locale('en', 'US'))
  static Locale getSystemLocale() {
    final localeName = Platform.localeName;

    // Parse locale string (formats: "en", "en_US", "en-US", "en_US.UTF-8")
    final cleaned = localeName.split('.').first; // Remove .UTF-8 suffix
    final parts = cleaned.split(RegExp(r'[_-]')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) {
      return const Locale('en');
    }

    if (parts.length >= 2) {
      return Locale(parts[0], parts[1].toUpperCase());
    }
    return Locale(parts[0]);
  }
}
