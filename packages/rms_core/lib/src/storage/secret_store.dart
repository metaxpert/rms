import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for credentials only — access and refresh tokens.
///
/// Behind an interface for two reasons: unit tests must not touch the platform
/// keystore (there is none on a CI runner), and managed-device deployments may
/// later need a different backing store.
///
/// Nothing non-sensitive belongs here; ordinary settings go to
/// `shared_preferences`, which is faster and not size-limited.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Production implementation: Android Keystore / iOS Keychain.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // v11's defaults are already the hardened path: AES-GCM data
              // encryption with RSA-OAEP key wrapping in the Android Keystore
              // (API 23+). The old `encryptedSharedPreferences` flag was removed
              // because that behaviour is no longer optional.
              aOptions: AndroidOptions(),
              // first_unlock_this_device: readable after the first unlock following
              // a reboot (so a tablet rebooting mid-service does not lock staff out
              // of a background refresh), but never migrated to another device.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Test/desktop fallback. Explicitly NOT secure — never selected in a release
/// build; a caller must opt into it.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}
