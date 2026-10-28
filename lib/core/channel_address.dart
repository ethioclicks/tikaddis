import '../models/models.dart';

/// Accepts full web URLs and resolves platform handles into usable web links.
String? channelAddress(String value, AccountType? platform) {
  final address = value.trim();
  if (address.isEmpty || address.length > 255) return null;
  final uri = Uri.tryParse(address);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty) {
    return address;
  }
  final handle = address.startsWith('@') ? address.substring(1) : address;
  if (!RegExp(r'^[\p{L}\p{N}_.-]{1,100}$', unicode: true).hasMatch(handle)) {
    return null;
  }
  return switch (platform?.wire) {
    'TELEGRAM' => 'https://t.me/$handle',
    'YOUTUBE' => 'https://www.youtube.com/@$handle',
    'TIKTOK' => 'https://www.tiktok.com/@$handle',
    'FACEBOOK' => 'https://www.facebook.com/$handle',
    'INSTAGRAM' => 'https://www.instagram.com/$handle',
    _ => null,
  };
}
