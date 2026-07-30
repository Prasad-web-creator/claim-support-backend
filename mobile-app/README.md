# Claim Support - Mobile App

This is the cross-platform mobile application for Claim Support, built with Flutter.

## Architecture

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Networking**: Dio
- **Platforms**: Android, iOS

## Getting Started

### Prerequisites

- Flutter SDK (latest stable release)
- Android Studio (for Android emulation) or Xcode (for iOS simulation)
- An active backend server running locally or remotely

### Installation

1. Navigate to the mobile app directory:
   ```bash
   cd mobile-app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

To run the app on a connected device or emulator:
```bash
flutter run
```

## Structure
- `/lib/screens` - UI views for the application
- `/lib/widgets` - Reusable UI components
- `/lib/models` - Data models mapping backend responses
- `/lib/services` - API integration using Dio
- `/lib/providers` - Riverpod state providers
- `/android` & `/ios` - Native platform configuration folders

> **Note**: Build artifacts, plugins, and generated code are ignored by Git. Do not commit local properties or keystores to the repository.
