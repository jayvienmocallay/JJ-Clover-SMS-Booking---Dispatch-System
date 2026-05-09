class PhoneNumberUtils {
  const PhoneNumberUtils._();

  static final RegExp _acceptedCustomerPhone = RegExp(r'^09\d{9}$');

  /// Normalizes Philippine mobile numbers to the local 09XXXXXXXXX format.
  ///
  /// Accepts common forms such as +639171234567, 639171234567,
  /// 09171234567, and values with spaces or punctuation.
  /// Returns a trimmed fallback string for unrecognized formats
  /// (e.g., short codes, alphanumeric senders) instead of collapsing
  /// everything to an empty string.
  static String normalize(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('63')) {
      return '0${digits.substring(2)}';
    }

    if (digits.length == 11 && digits.startsWith('09')) {
      return digits;
    }

    if (digits.length == 10 && digits.startsWith('9')) {
      return '0$digits';
    }

    if (digits.isNotEmpty) {
      return digits;
    }

    return trimmed;
  }

  /// Returns true for customer-entered phone numbers accepted by the UI.
  static bool isAcceptedCustomerPhone(String value) {
    return _acceptedCustomerPhone.hasMatch(value);
  }

  /// Returns true if [value] looks like a valid Philippine mobile number
  /// after normalization. Use this to reject short codes and garbage senders.
  static bool isValidMobileNumber(String value) {
    final normalized = normalize(value);
    return _acceptedCustomerPhone.hasMatch(normalized);
  }
}
