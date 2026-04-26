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

- [ ] Replace pre-book pending string serialization with JSON.
  - [ ] Store pending pre-book contexts as JSON in `app_settings`.
  - [ ] Support migration/fallback from the current delimiter format.
  - [ ] Test addresses containing `~` or `|`.

- [ ] Generate the SQLCipher key with secure randomness.
  - [ ] Replace timestamp-based key text with `Random.secure()`.
  - [ ] Store the generated key in `flutter_secure_storage`.
  - [ ] Preserve compatibility for existing installed databases.

## Platform And Build

- [ ] Decide whether web is supported.
  - [ ] If web is not supported, remove or hide misleading web paths.
  - [ ] If web is supported, add conditional imports for database/platform services.
  - [ ] Verify `flutter build web` behavior after the decision.

- [ ] Track Gradle deprecation warnings.
  - [ ] Record that current warnings are from Flutter/dependency build scripts.
  - [ ] Recheck warnings after dependency upgrades.
  - [ ] Avoid upgrading to Gradle 10 until warnings are resolved upstream.

## Tests To Add

- [ ] Database test: foreign key cascades and `ON DELETE SET NULL`.
- [ ] Database test: duplicate customer phone numbers are rejected.
- [ ] Database test: edited phone numbers are normalized.
- [ ] Provider/service test: completing an order creates one delivery log.
- [x] SMS service test: foreground async processing failures do not crash the listener.
- [ ] Pre-book persistence test: JSON round-trip with special characters in address.

## Verification Commands

- [ ] Run `flutter analyze --no-pub`.
- [ ] Run `flutter test --no-pub`.
- [ ] Run `.\gradlew.bat :app:compileDebugKotlin --offline` from `android`.
- [ ] Manually test Android SMS flow on a device:
  - [ ] Default SMS app request.
  - [ ] `DELIVER [qty]`.
  - [ ] Wrong-day pre-book offer and `YES`.
  - [ ] `DROP [qty]` alarm.
  - [ ] Duplicate SMS handling.
