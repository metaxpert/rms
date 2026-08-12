/// Build-time environment selection (brief §30).
///
/// Chosen with `--dart-define=RMS_ENV=staging`; defaults to production so a
/// release build can never accidentally ship pointing at a developer's laptop.
/// No secrets live here — only endpoints, which are not confidential.
enum Environment {
  development,
  staging,
  production;

  static const _key =
      String.fromEnvironment('RMS_ENV', defaultValue: 'production');

  static Environment get current => switch (_key) {
        'development' || 'dev' => Environment.development,
        'staging' || 'stage' => Environment.staging,
        _ => Environment.production,
      };

  bool get isProduction => this == Environment.production;

  /// Default API base URL for this environment.
  ///
  /// Staff can still override it on the sign-in screen (a restaurant may be on
  /// a LAN address), but the default must be right so nobody has to type a URL
  /// they don't know. `--dart-define=RMS_API_BASE=...` wins over all of these,
  /// which is how CI builds per-customer APKs.
  String get defaultApiBase {
    const override = String.fromEnvironment('RMS_API_BASE');
    if (override.isNotEmpty) return override;
    return switch (this) {
      // 10.0.2.2 is how the Android emulator reaches the host machine.
      Environment.development => 'http://10.0.2.2:3300',
      Environment.staging => 'https://staging.metaxperts.net/api',
      Environment.production => 'https://rms.metaxperts.net/api',
    };
  }

  /// Socket.IO endpoint. The gateway is mounted on the same origin as the API;
  /// the `/api` path prefix is stripped because the websocket namespace is at
  /// the root (see ARCHITECTURE.md §4).
  String socketBase(String apiBase) {
    final trimmed = apiBase.replaceAll(RegExp(r'/api/?$'), '');
    return trimmed.isEmpty ? apiBase : trimmed;
  }

  /// Verbose logging is a liability in production — logs on a shared restaurant
  /// tablet are readable by anyone who plugs it into a laptop.
  bool get verboseLogging => this != Environment.production;

  String get label => switch (this) {
        Environment.development => 'DEV',
        Environment.staging => 'STAGING',
        Environment.production => 'PROD',
      };
}
