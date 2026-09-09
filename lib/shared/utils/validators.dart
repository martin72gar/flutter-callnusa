class Validators {
  const Validators._();

  // Deliberately permissive: the backend is the authority on what a valid
  // account address is. This only catches obvious typos before a round trip.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  /// Digits plus the characters a SIP URI user part may legitimately contain.
  static final RegExp _dialable = RegExp(r'^[0-9*#+]+$');

  static bool isDialable(String value) =>
      value.isNotEmpty && _dialable.hasMatch(value);
}
