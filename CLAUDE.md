# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**litmusic** — A Flutter music app for boats ("BoatMusic"). Currently at initial scaffold stage (default Flutter counter template).

- **Language**: Dart 3.12+
- **Framework**: Flutter (multi-platform: Android, iOS, macOS, Windows)
- **Package name**: `litmusic`
- **Version**: 1.0.0+1

## Commands

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Run on a specific platform
flutter run -d windows
flutter run -d android
flutter run -d macos
flutter run -d ios

# Analyze code for issues
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build for a platform
flutter build apk
flutter build ios
flutter build macos
flutter build windows

# Add a dependency
flutter pub add <package_name>

# Update dependencies
flutter pub upgrade --major-versions
```

## Architecture

### Current structure (scaffold stage)

```
litmusic/
├── lib/
│   └── main.dart              # App entry point, MaterialApp config, home page widget
├── test/
│   └── widget_test.dart       # Widget smoke test for counter
├── android/                   # Android platform project (Kotlin)
├── ios/                       # iOS platform project (Swift)
├── macos/                     # macOS platform project (Swift)
├── windows/                   # Windows platform project (C++)
├── pubspec.yaml               # Project manifest, dependencies, assets config
├── analysis_options.yaml      # Dart linter rules (extends flutter_lints)
└── .gitignore                 # Flutter-standard ignores
```

### Key conventions

- **State management**: Currently uses `setState` (default). As the project grows, consider adopting a state management solution (Riverpod, BLoC, or Provider).
- **Dart analysis**: Uses the `flutter_lints` recommended lint set defined in `analysis_options.yaml`. Custom lint rules can be added there.
- **Material Design**: Uses `MaterialApp` with `colorScheme` theming via `ColorScheme.fromSeed`.

## Development Guidelines

- Run `flutter analyze` before committing to catch lint and type errors.
- All new widgets should be placed in `lib/` organized by feature or component layer as the app grows.
- Use `const` constructors for widgets where possible to improve performance.
- Match the Flutter standard patterns for assets, fonts, and theming defined in `pubspec.yaml`.
- Tests live in `test/` and should mirror the `lib/` structure.
