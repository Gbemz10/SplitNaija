/// Nigeria-only phone handling — no country picker anywhere in the app,
/// so every entry point normalizes to the same `+234XXXXXXXXXX` shape
/// before it ever reaches the backend.
library;

/// Turns whatever a user typed into the local 10-digit part of a Nigerian
/// number (drops a leading 0, drops a typed `+234`/`234`, strips spaces).
String _localDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('234')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return digits;
}

/// Formats raw input into `+234XXXXXXXXXX` for sending to the backend.
String toE164Nigeria(String raw) => '+234${_localDigits(raw)}';

/// True once there are enough digits to plausibly be a full Nigerian
/// mobile number (10 digits after the country code).
bool isLikelyValidNigerianPhone(String raw) => _localDigits(raw).length == 10;
