# JJ Clover SMS Booking & Dispatch System

JJ Clover is an Android-first Flutter app for SMS-based water delivery booking
and dispatch. It receives customer SMS commands, validates delivery zones,
stores encrypted operational data, and helps staff track orders, schedules,
customers, messages, and delivery logs.

## SMS Guide

For a learner-friendly walkthrough of the Android SMS receiver, Dart command
router, supported commands, replies, storage, and troubleshooting flow, see
[`docs/SMS_SYSTEM_GUIDE.md`](docs/SMS_SYSTEM_GUIDE.md).

## Platform Support

Supported:

- Android

Not supported:

- Web

Web is intentionally unsupported because the product depends on Android SMS
permissions, default SMS app behavior, background SMS entry points, SQLCipher
database access, and secure platform storage. The browser target would not be
able to run the core booking and dispatch workflows, so the `web/` Flutter
platform scaffold is not included.

## Development Checks

Run the normal Flutter checks before handing off changes:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

## Android Release Signing

Release builds must use a private Android keystore. Copy
`android/key.properties.example` to `android/key.properties`, place the keystore
at the configured `storeFile` path, and replace the placeholder passwords and
alias. `android/key.properties` and keystore files are ignored by Git.

CI can provide the same values with environment variables:

```sh
ANDROID_RELEASE_STORE_FILE
ANDROID_RELEASE_STORE_PASSWORD
ANDROID_RELEASE_KEY_ALIAS
ANDROID_RELEASE_KEY_PASSWORD
```
