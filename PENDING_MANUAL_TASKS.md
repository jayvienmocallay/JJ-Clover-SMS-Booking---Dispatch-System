# JJ Clover SMS Dispatch System — Pending Manual Tasks

Items that require manual setup, physical device access, or human intervention.
These cannot be completed through code alone.

---

## CRITICAL (Blocking)

- [ ] **Add `alarm.mp3` audio file** — Place an MP3 file at `assets/audio/alarm.mp3` for the DROP walk-in alert. Without it, the alarm service will fail at runtime. Recommended: 10+ second duration, loud tone suitable for staff alerting.

- [ ] **Build & install APK on Android device** — No Android SDK on this machine. Run `flutter build apk --release` on a machine with Android Studio, then install on the target tablet/phone.

---

## HIGH PRIORITY (Requires Android Device)

- [ ] **Test SMS receiving end-to-end** — Send real SMS messages (DELIVER 5, DROP 2, YES, STATUS) to the device SIM number and verify background service processes them correctly.

- [ ] **Test walk-in alarm on device** — Trigger a DROP order via SMS and verify the alarm plays at full volume with the overlay alert displayed.

- [ ] **Test Android notification channel** — Verify foreground service notification appears in the status bar while the SMS background listener is active.

- [ ] **Verify SQLCipher encryption** — Confirm the database is encrypted on first launch and that re-opening the app restores data correctly.

- [ ] **Test pre-book flow** — Send a DELIVER order on a wrong day, verify the pre-book prompt reply, then send YES and verify the order is queued for the next valid delivery day.

---

## MEDIUM PRIORITY (Feature Gaps)

- [ ] **Persist cutoff time changes** — Settings screen allows editing the cutoff time, but changes are in-memory only and reset on app restart. Needs SharedPreferences or database storage.

- [ ] **Add zone selection when adding barangays** — New barangays added in Settings default to Zone A. Need a zone dropdown (A/B/C) during add.

- [ ] **Staff assignment management** — Database supports `staff_id` on orders and delivery logs, but there is no UI to add staff members or assign them to orders.

- [ ] **Shift-end reconciliation screen** — Database has `delivery_logs` CRUD, but no UI for viewing daily totals, gallon accountability, or generating shift-end reports.

- [ ] **Persist pre-book pending context** — The `_preBookPending` map in `SmsBackgroundService` is in-memory only. If the app crashes between the pre-book prompt and the customer's YES reply, context is lost.

---

## LOW PRIORITY (Nice-to-Have)

- [ ] **Integration tests (Task 013)** — End-to-end tests for SMS background service to database to UI update flow. Requires Android emulator or device.

- [ ] **Widget tests for UI screens** — No widget tests for Dashboard, Orders, Customers, Messages, or Settings screens.

- [ ] **Timezone configuration** — All timestamps use `DateTime.now()` with no timezone handling. If the device timezone differs from the business location, times will be wrong.

- [ ] **Make Zone C barangay-day mapping database-driven** — Currently hardcoded in `ZoneScheduleMap.zoneCBarangayDays`. Making it editable would allow adding new Zone C barangays with custom delivery days from the UI.

- [ ] **Configurable auto-refresh interval** — Dashboard auto-refresh is hardcoded to 15 seconds in `app_shell.dart`. Could be user-configurable.

- [ ] **Analytics / historical reporting** — Dashboard shows today's stats only. No historical trends, delivery completion rates, or zone utilization views.

---

## WEB PLATFORM LIMITATIONS (By Design)

The Chrome web build is for **UI preview only**. The following features are intentionally disabled on web via `kIsWeb` guards:

| Feature | Reason |
|---|---|
| Database (SQLCipher) | No native SQLite support on web |
| SMS receiving | Android-only `telephony` package |
| Background service | Android foreground service only |
| Audio alarm | `audioplayers` asset source not available on web |
| Pull-to-refresh | No data to refresh without database |
| Delivery logs | Requires database access |

---

## REMAINING TASK TRACKER (from SRS)

| Task | Status | Notes |
|---|---|---|
| Task 001-009 | Done | Core logic, models, services, tests |
| Task 010 | Done | All 5 UI screens implemented |
| Task 011 | Done | Provider/StreamBuilder real-time UI |
| Task 012 | Partial | Alarm service code done, needs `alarm.mp3` file |
| Task 013 | Partial | Integration wiring done, end-to-end tests need Android device |
| Task 014 | Not started | Field testing with real SIM + customers |
| Task 015 | Not started | Deployment (APK build + install) |
| Task 016 | Not started | User evaluation & feedback |
| Task 017 | Not started | Documentation & handoff |

---

*Last updated: 2026-03-08*