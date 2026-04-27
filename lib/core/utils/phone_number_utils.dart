class PhoneNumberUtils {
  const PhoneNumberUtils._();

  static final RegExp _acceptedCustomerPhone = RegExp(r'^09\d{9}$');

  /// Normalizes Philippine mobile numbers to the local 09XXXXXXXXX format.
  ///
  /// Accepts common forms such as +639171234567, 639171234567,
  /// 09171234567, and values with spaces or punctuation.
  static String normalize(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('63')) {
      return '0${digits.substring(2)}';
    }

    if (digits.length == 10 && digits.startsWith('9')) {
      return '0$digits';
    }

    return digits;
  }

  /// Returns true for customer-entered phone numbers accepted by the UI.
  static bool isAcceptedCustomerPhone(String value) {
    return _acceptedCustomerPhone.hasMatch(value);
  }
}
