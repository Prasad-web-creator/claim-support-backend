# Claim Support Monorepo

Welcome to the Claim Support application repository. This is a monorepo containing both the backend REST API and the mobile application.

## Repository Structure

- `/backend` - The Node.js, Express, and MongoDB backend.
- `/mobile-app` - The Flutter (Dart) mobile application for iOS and Android.

## Setup Instructions

This repository separates concerns strictly. Please refer to the dedicated README files in each sub-directory for specific instructions on how to set up, build, and run each project.

- [Backend Documentation](./backend/README.md)
- [Mobile App Documentation](./mobile-app/README.md)

## Development Workflow

- **Backend**: Requires Node.js and MongoDB. Uses `npm` for dependency management.
- **Mobile**: Requires the Flutter SDK and respective native tooling (Android Studio / Xcode). Uses `flutter pub` for dependency management.

Please do not commit `.env` files or API secrets into this repository. Ensure `uploads/` and local caches remain ignored.
