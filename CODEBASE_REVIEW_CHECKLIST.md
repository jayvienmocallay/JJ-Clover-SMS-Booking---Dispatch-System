# Codebase Review Checklist

Use this checklist to track fixes and follow-up work from the April 26, 2026 codebase review.

## Critical Fixes

- [ ] Enable SQLite foreign key enforcement in `DatabaseHelper.openDatabase`.
  - [ ] Add `onConfigure` with `PRAGMA foreign_keys = ON`.
  - [ ] Add or run a migration check to confirm cascades work for customers, schedules, orders, and delivery logs.
  - [ ] Verify deleting a customer leaves order history consistent and removes dependent schedules/logs as intended.

- [ ] Harden customer phone number identity.
  - [ ] Normalize `contact_number` in `DatabaseHelper.updateCustomer`.
  - [ ] Validate edited phone numbers using the same accepted format as customer creation.
  - [ ] Add a unique index on normalized `customers.contact_number`.
  - [ ] Handle duplicate phone update errors with a clear UI message.

- [ ] Wire delivery completion to delivery log creation.
  - [ ] Create a delivery log when an order is marked `completed`.
  - [ ] Save `order_id`, `customer_id`, delivered quantity, gallon type, staff ID if available, notes if available, and `delivered_at`.
  - [ ] Perform status update and log insert in a single transaction.
  - [ ] Confirm the completed order detail view shows the new delivery log.

## Reliability Improvements

- [x] Catch foreground SMS processing errors from `listenIncomingSms`.
  - [x] Await or explicitly `unawaited` the processing Future with error handling.
  - [x] Ensure failed receipts are recorded without uncaught async errors.
  - [x] Add a regression test or manual test note for malformed SMS/background failures.

- [x] Replace pre-book pending string serialization with JSON.
  - [x] Store pending pre-book contexts as JSON in `app_settings`.
  - [x] Support migration/fallback from the current delimiter format.
  - [x] Test addresses containing `~` or `|`.

- [x] Generate the SQLCipher key with secure randomness.
  - [x] Replace timestamp-based key text with `Random.secure()`.
  - [x] Store the generated key in `flutter_secure_storage`.
  - [x] Preserve compatibility for existing installed databases.

## Platform And Build

- [x] Decide whether web is supported.
  - [x] Web is not supported; remove misleading `web/` platform scaffold.
  - [x] Not applicable: web is unsupported, so no conditional imports were added.
  - [x] Verify `flutter build web --no-pub` fails with "This project is not configured for the web."

- [x] Track Gradle deprecation warnings.
  - [x] Recorded April 26, 2026: `.\gradlew.bat :app:compileDebugKotlin --offline --warning-mode all --console=plain` succeeds on Gradle 8.12.
  - [x] Current Gradle 10 removal warnings are from Flutter/dependency build scripts, not app-owned Gradle files:
    `audioplayers_android`, `flutter_background_service_android`, `flutter_secure_storage`,
    `permission_handler_android`, `sqflite_sqlcipher`, `telephony`, and Flutter's `:app:compileFlutterBuildDebug` task.
  - [x] Recheck warnings with the same command after Flutter or pub dependency upgrades.
  - [x] Avoid upgrading to Gradle 10 until these upstream warnings are resolved.

## Tests To Add

- [x] Database test: foreign key cascades and `ON DELETE SET NULL`.
- [x] Database test: duplicate customer phone numbers are rejected.
- [x] Database test: edited phone numbers are normalized.
- [x] Provider/service test: completing an order creates one delivery log.
- [x] SMS service test: foreground async processing failures do not crash the listener.
- [x] Pre-book persistence test: JSON round-trip with special characters in address.

## Verification Commands

- [x] Run `flutter analyze --no-pub`.
- [x] Run `flutter test --no-pub`.
- [x] Run `.\gradlew.bat :app:compileDebugKotlin --offline` from `android`.
- [ ] Manually test Android SMS flow on a device:
  - [ ] Default SMS app request.
  - [ ] `DELIVER [qty]`.
  - [ ] Wrong-day pre-book offer and `YES`.
  - [ ] `DROP [qty]` alarm.
  - [ ] Duplicate SMS handling.
