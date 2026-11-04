/// Phone number handling shared by login, register and password reset.
///
/// The backend only compares the LAST 9 DIGITS of a phone number, so users
/// may type it as `+251 912 345 678`, `251912345678`, `0912345678` or just
/// `912345678` and all of them identify the same account.
class Phone {
  Phone._();

  /// Fewest digits accepted: the 9 significant digits.
  static const minDigits = 9;

  /// Most digits accepted: 9 significant digits plus the 251 country code.
  static const maxDigits = 12;

  /// Digits only, with spaces, dashes, brackets and the leading `+` removed.
  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// The last 9 digits, or null when the input is too short or too long.
  static String? last9(String raw) {
    final d = digits(raw);
    if (d.length < minDigits || d.length > maxDigits) return null;
    return d.substring(d.length - minDigits);
  }

  /// Canonical form sent to the backend: `0` + the last 9 digits
  /// (e.g. `0912345678`). Returns null for invalid input.
  static String? normalize(String raw) {
    final n = last9(raw);
    return n == null ? null : '0$n';
  }

  /// Form-field validator. Returns an error message or null when valid.
  static String? validate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter your phone number';
    final d = digits(value);
    if (d.length < minDigits) return 'Phone number is too short';
    if (d.length > maxDigits) return 'Phone number is too long';
    return null;
  }
}
