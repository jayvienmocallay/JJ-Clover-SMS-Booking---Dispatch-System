// Task 020 — Hardcoded RA 10173-compliant SMS copy for self-registration
//
// All customer-facing strings used by the SMS registration and data-rights
// flows live here so that the wording is reviewed in one place. The privacy
// notice mirrors the Customer Registration screen UI (RA 10173, Data Privacy
// Act of 2012) so the on-record consent statement is consistent across
// channels. Bump [consentVersion] whenever the wording materially changes
// so existing customers can be re-prompted if needed.

/// Centralized RA 10173 consent and registration SMS copy.
class SmsRegistrationCopy {
  const SmsRegistrationCopy._();

  /// Bump when the privacy notice wording changes materially.
  static const String consentVersion = 'v1';

  /// Channel tag stored on `customers.consent_channel` for SMS-registered users.
  static const String channelSms = 'sms';

  /// Channel tag stored on `customers.consent_channel` for staff/UI registrations.
  static const String channelAppUi = 'app_ui';

  /// Lifetime of an in-progress registration or delete-confirm flow.
  /// Older rows are pruned on each interaction.
  static const Duration pendingActionTtl = Duration(minutes: 30);

  // --- Registration flow ---

  /// Step 1 — sent after `REGISTER [name]` is received from a new number.
  /// Mirrors the privacy notice on the Customer Registration screen
  /// (lib/ui/screens/customers_screen.dart) so consent statements match.
  static String registrationConsent({required String name}) =>
      'Hi $name! JJ Clover Water Delivery (RA 10173, Data Privacy Act of 2012) '
      'will collect your name, phone number, barangay, and delivery address — '
      'used only to process orders, contact you about deliveries, and improve '
      'our service. Your data will not be shared with third parties without '
      'your consent. Text MYDATA anytime to view your data, or DELETEDATA to '
      'remove it. Reply AGREE to consent and continue, or STOP to cancel.';

  /// Step 2 — sent after AGREE.
  static String askBarangay(String validBarangays) =>
      'Consent recorded. Reply BARANGAY [name] to continue. '
      'Available barangays: $validBarangays.';

  /// Step 3 — sent after a valid BARANGAY is provided.
  static const String askAddress =
      'Reply ADDRESS [your full delivery address]. '
      'Example: ADDRESS Purok 4 near the chapel.';

  /// Final — sent after ADDRESS is provided and the customer record is created.
  static String registrationComplete({
    required String name,
    required String barangay,
  }) =>
      'Registered! $name in $barangay. You can now text DELIVER [qty] to order. '
      'Text MYDATA to view your data or DELETEDATA to remove it anytime.';

  /// Sent when the customer texts STOP during registration.
  static const String registrationCancelled =
      'Registration cancelled. Your data has not been saved. Reply REGISTER '
      '[your full name] anytime to start again.';

  /// Sent when AGREE arrives without an active registration in progress.
  static const String noPendingRegistration =
      'No registration in progress. Reply REGISTER [your full name] to start.';

  /// Sent during awaiting_consent if anything other than AGREE/STOP arrives.
  static const String consentRequired =
      'Please reply AGREE to consent to data collection, or STOP to cancel '
      'registration.';

  /// Sent during awaiting_barangay if the input is invalid or missing.
  static const String invalidBarangay =
      'Barangay not recognized. Reply BARANGAY [valid name] to continue, '
      'or STOP to cancel.';

  /// Sent during awaiting_barangay if a non-BARANGAY command arrives.
  static const String barangayPromptReminder =
      'Please reply BARANGAY [name] to continue registration, or STOP to cancel.';

  /// Sent during awaiting_address if a non-ADDRESS command arrives.
  static const String addressPromptReminder =
      'Please reply ADDRESS [your full delivery address], or STOP to cancel.';

  /// Sent when a known number sends REGISTER.
  static const String alreadyRegistered =
      'You are already registered. Text DELIVER [qty] to order, MYDATA to view '
      'your data, or DELETEDATA to remove it.';

  /// Sent when REGISTER arrives without a name argument.
  static const String registerHelp =
      'Reply REGISTER [your full name] to register. Example: REGISTER Juan Dela Cruz.';

  /// Replaces the old "Unknown number. Please register first..." reply so
  /// new senders always see the self-registration path.
  static const String unknownNumberPrompt =
      'Unknown number. Reply REGISTER [your full name] to register. '
      'Example: REGISTER Juan Dela Cruz. Or call the station.';

  /// Sent once, the first time any mobile number texts the app.
  static const String firstContactWelcome =
      'Hi! This is an automated response from JJ Clover Water Refilling '
      'Station for field testing.\n\n'
      'To order water delivery, text:\n'
      'DELIVER [qty] - e.g. DELIVER 5\n'
      'DELIVER [qty] NEW - for new gallons\n'
      'DROP [qty] - for walk-in pickup\n'
      'STATUS - to check station status\n\n'
      'Your message will be processed automatically.';

  /// Sent with [firstContactWelcome] when the first-time sender is not yet in
  /// the customer database.
  static const String firstContactPrivacyNotice =
      'You are not yet registered in our system. Under the Data Privacy Act '
      '(RA 10173), we need your consent before storing your information. '
      'To register, reply REGISTER [your full name].';

  // --- Data subject rights (MYDATA / DELETEDATA / OPTOUT) ---

  /// Reply to MYDATA — shows the personal data on file (RA 10173 right to access).
  static String myData({
    required String name,
    required String phone,
    required String barangay,
    String? address,
  }) {
    final addressLine = (address != null && address.trim().isNotEmpty)
        ? '\nAddress: $address'
        : '';
    return 'Your data on file:\n'
        'Name: $name\n'
        'Phone: $phone\n'
        'Barangay: $barangay'
        '$addressLine\n'
        'Reply DELETEDATA to permanently remove your data.';
  }

  /// Sent when MYDATA / DELETEDATA / OPTOUT comes from a number with no record.
  static const String noDataOnFile =
      'No data found for this number. Reply REGISTER [your full name] to register.';

  /// Confirmation prompt that warns deletion is permanent (RA 10173 right to erasure).
  static const String deleteWarning =
      'WARNING: This will PERMANENTLY delete your customer profile, schedules, '
      'and message history. This CANNOT be undone. Reply CONFIRM DELETE within '
      '30 minutes to proceed, or any other text to cancel.';

  /// Sent when the customer cancels the deletion (anything except CONFIRM DELETE).
  static const String deleteCancelled =
      'Deletion cancelled. Your data has not been changed.';

  /// Sent after the customer record (and related personal data) is removed.
  static const String deleteComplete =
      'Your data has been permanently deleted. Thank you for using JJ Clover.';

  /// Sent when CONFIRM DELETE arrives without a pending delete request.
  static const String confirmDeleteWithoutRequest =
      'No pending deletion request. Reply DELETEDATA first if you wish to '
      'remove your data.';
}
