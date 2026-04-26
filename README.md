# JJ Clover SMS Booking & Dispatch System

JJ Clover is an Android-first Flutter app for SMS-based water delivery booking
and dispatch. It receives customer SMS commands, validates delivery zones,
stores encrypted operational data, and helps staff track orders, schedules,
customers, messages, and delivery logs.

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
