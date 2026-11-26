/// Build-time configuration, supplied via `--dart-define`.
///
/// CI bakes the production API URL in:
/// `flutter build apk --dart-define=API_BASE_URL=https://api.qrsafe.flemby.com`.
/// The default targets the Android emulator's host-loopback address so a local
/// `flutter run` talks to a backend on the developer's machine.
class Env {
  const Env._();

  /// Base URL of the QRSafe API. No trailing slash.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator -> host localhost
  );

  /// User-facing app version, shown on the Settings screen.
  ///
  /// CI passes the real one straight from pubspec, because a hand-typed
  /// constant drifts: this said 0.1.0 while the app shipped as 1.0.0, so the
  /// screen could not answer the one question it exists to answer — which
  /// build is on the phone. A local `flutter run` shows "dev".
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );
}
