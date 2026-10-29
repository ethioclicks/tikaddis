import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Long-lived per-device renewal credential, held in Keychain/Android Keystore.
class SessionCredentials {
  final FlutterSecureStorage storage;
  const SessionCredentials({this.storage = const FlutterSecureStorage()});
  Future<String?> read() => storage.read(key: 'sessionRenewal');
  Future<void> write(String value) =>
      storage.write(key: 'sessionRenewal', value: value);
  Future<void> clear() => storage.delete(key: 'sessionRenewal');
}
