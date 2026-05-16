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

  /// Canonical barangay names for SMS registration (fuzzy matches allowed).
  static const List<String> validBarangays = [
    'Dagohoy',
    'Gabuyan',
    'Katipunan',
    'Poblacion',
    'San Isidro',
    'San Jose',
    'Santa Rosa',
    'Santo Nino',
    'Semong',
    'Tiburcia',
  ];

  static String get validBarangaysText => validBarangays.join(', ');

  /// Success reply — consent is embedded per RA 10173 (no separate AGREE step).
  static String registrationComplete({
    required String name,
    required String barangay,
    required String address,
  }) =>
            '\u2705 Registered! $name | $barangay | $address\n'
      'Data collected per RA 10173. Text MYDATA to view or DELETEDATA to remove '
      'your data anytime.\n'
      'You can now text DELIVER [qty] to order.';

  /// Sent when REGISTER is missing required fields.
  static const String registerMissingFields =
      'Incomplete info. Please text:\n'
      'REGISTER [name], [barangay], [address]\n'
      'Example: REGISTER Juan, Katipunan, Purok 1-A';

  /// Sent when REGISTER is not used.
  static const String registerWrongFormat =
      'To register, text:\n'
      'REGISTER [name], [barangay], [address]\n'
      'Example: REGISTER Juan, Katipunan, Purok 1-A';

  /// Sent when the barangay is not recognized.
  static String invalidBarangay(String input) =>
      'Barangay "$input" not found.\n'
      'Valid barangays: $validBarangaysText.\n'
      'Please try again.';

  /// Sent when a known number sends REGISTER.
  static const String alreadyRegistered =
      'You are already registered. Text DELIVER [qty] to order, MYDATA to view '
      'your data, or DELETEDATA to remove it.';

    /// Sent when REGISTER arrives without required parts.
    static const String registerHelp = registerMissingFields;

    /// Shown to unregistered senders or unknown commands to route to REGISTER.
    static const String unknownNumberPrompt = registerWrongFormat;

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
      'You are not yet registered in our system. To register, text: '
      'REGISTER [name], [barangay], [address].';

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
