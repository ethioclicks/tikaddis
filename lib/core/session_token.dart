import 'dart:convert';

String? sessionUsername(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['sub'] is String
        ? payload['sub'] as String
        : null;
  } catch (_) {
    return null;
  }
}

/// Reads expiry only to prompt reauthentication; the server validates the token.
bool isSessionTokenExpired(String token, {DateTime? now}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map || payload['exp'] is! num) return false;
    final expiry = (payload['exp'] as num).toDouble();
    return expiry <= (now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
  } on FormatException {
    // Unknown token formats remain the server's responsibility.
    return false;
  }
}
