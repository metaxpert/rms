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

  /// Socket.IO endpoint. The gateway is mounted on the same origin **and the
  /// same path prefix** as the API, so this hands the API base over as it is,
  /// bar a trailing slash.
  ///
  /// It used to strip a trailing `/api`, on the reasoning that the websocket
  /// namespace sits at the root. That is true of the API reached directly on
  /// its own port, which is how it is reached in development — and false behind
  /// a reverse proxy that mounts the API under `/api/`, which is how it is
  /// reached in production. There, stripping the prefix aimed the socket at the
  /// *web console's* origin, where `/socket.io/` is the Next.js app.
  ///
  /// It failed silently, which is the interesting part: the socket is
  /// deliberately an accelerator and never the source of truth (ARCHITECTURE.md
  /// §4), so every screen still refreshed on resume and on its slow poll.
  /// Nothing looked broken. It was simply never live, in the one environment
  /// nobody could reproduce on a laptop.
  ///
  /// Splitting this into an origin and a path is Socket.IO's own business — a
  /// path in the URL it is handed is a *namespace*, not a prefix — so the
  /// transport does it. See [socketIoTarget].
  String socketUrl(String apiBase) {
    var trimmed = apiBase.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
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
