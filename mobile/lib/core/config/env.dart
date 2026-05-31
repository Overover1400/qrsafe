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

  /// User-facing app version, surfaced on the Settings screen.
  static const appVersion = '0.1.0';
}
