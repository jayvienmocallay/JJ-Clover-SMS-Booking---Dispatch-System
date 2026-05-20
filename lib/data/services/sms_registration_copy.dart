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
                                                'Nakarehistro na! $name | $barangay | $address\n'
            'Gikolekta ang data sumala sa RA 10173. I-text ang MYDATA para makita o '
            'DELETEDATA para tangtangon ang imong data bisan kanusa.\n'
                        'Pwede na ka mo-text ug DELIVER [kadaghanon] o DROP [kadaghanon] para mo-order.';

  /// Sent when REGISTER is missing required fields.
  static const String registerMissingFields =
      'Kulangan ang impormasyon. Palihug i-text:\n'
      'REGISTER [name], [barangay], [address]\n'
      'Pananglitan: REGISTER Juan, Katipunan, Purok 1-A\n'
      'Gikuha namo ang imong ngalan, numero sa telepono, barangay, ug adres para '
      'sa pagproseso sa order. Sa pagrehistro, miuyon ka sa abiso sa Data Privacy '
      'Act sa app.';

  /// Sent when REGISTER is not used.
  static const String registerWrongFormat =
      'Para marehistro, i-text:\n'
      'REGISTER [name], [barangay], [address]\n'
      'Pananglitan: REGISTER Juan, Katipunan, Purok 1-A\n'
      'Gikuha namo ang imong ngalan, numero sa telepono, barangay, ug adres para '
      'sa pagproseso sa order. Sa pagrehistro, miuyon ka sa abiso sa Data Privacy '
      'Act sa app.';

  /// Sent when the barangay is not recognized.
  static String invalidBarangay(String input) =>
      'Wala makita ang barangay "$input".\n'
      'Valid nga barangay: $validBarangaysText.\n'
      'Palihug sulayi pag-usab.';

  /// Sent when a known number sends REGISTER.
  static const String alreadyRegistered =
      'Nakarehistro na ka. I-text ang DELIVER [kadaghanon] o DROP [kadaghanon] para mo-order, '
      'MYDATA para makita ang imong data, o DELETEDATA para tangtangon kini.';

    /// Sent when REGISTER arrives without required parts.
    static const String registerHelp = registerMissingFields;

    /// Shown to unregistered senders or unknown commands to route to REGISTER.
    static const String unknownNumberPrompt = registerWrongFormat;

  /// Sent once, the first time any mobile number texts the app.
  static const String firstContactWelcome =
      'Hi! Kini awtomatikong tubag gikan sa JJ Clover Water Refilling '
      'Station para sa field testing.\n\n'
      'Para mo-order ug water delivery, i-text:\n'
      'DELIVER [kadaghanon] - pananglitan DELIVER 5\n'
      'DROP [kadaghanon] - para sa walk-in pickup\n'
      'STATUS - para mahibal-an ang status sa estasyon\n\n'
      'Ang imong mensahe awtomatikong iproseso.';

  /// Sent with [firstContactWelcome] when the first-time sender is not yet in
  /// the customer database.
  static const String firstContactPrivacyNotice =
      'Wala pa ka narehistro sa among sistema. Gikuha namo ang imong ngalan, '
      'numero sa telepono, barangay, ug adres para sa pagproseso sa order. Sa '
      'pagrehistro, miuyon ka sa abiso sa Data Privacy Act sa app. Para '
      'marehistro, i-text: '
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
        ? '\nAdres: $address'
        : '';
    return 'Ang imong data sa rekord:\n'
        'Ngalan: $name\n'
        'Telepono: $phone\n'
        'Barangay: $barangay'
        '$addressLine\n'
        'Tubaga ang DELETEDATA para permanenteng tangtangon ang imong data.';
  }

  /// Sent when MYDATA / DELETEDATA / OPTOUT comes from a number with no record.
  static const String noDataOnFile =
      'Walay data para niini nga numero. Tubaga og REGISTER [imong tibuok '
      'ngalan] para marehistro.';

  /// Confirmation prompt that warns deletion is permanent (RA 10173 right to erasure).
  static const String deleteWarning =
      'PASIDAAN: Kini magpermanente nga delete sa imong customer profile, mga '
      'schedule, ug historya sa mensahe. DILI NI MABALIK. Tubaga og CONFIRM '
      'DELETE sulod sa 30 minutos para ipadayon, o bisan unsang lain nga text '
      'para kanselar.';

  /// Sent when the customer cancels the deletion (anything except CONFIRM DELETE).
  static const String deleteCancelled =
      'Gikanselar ang pagtangtang. Wala giusab ang imong data.';

  /// Sent after the customer record (and related personal data) is removed.
  static const String deleteComplete =
      'Permanente nang natangtang ang imong data. Salamat sa paggamit sa JJ Clover.';

  /// Sent when CONFIRM DELETE arrives without a pending delete request.
  static const String confirmDeleteWithoutRequest =
      'Walay pending nga request sa pagtangtang. Tubaga una og DELETEDATA kung '
      'gusto nimo tangtangon ang imong data.';
}
