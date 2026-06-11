import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrsafe_mobile/features/scan/presentation/scanner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // mobile_scanner talks to the platform over a method channel; stub it so the
  // controller's lifecycle calls (e.g. dispose) resolve instead of hanging in a
  // headless test.
  const channel =
      MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scanner controller is configured to detect QR codes', () {
    final controller = buildScannerController();
    addTearDown(controller.dispose);

    // Explicit QR format makes detection reliable (an empty format list can be
    // flaky); normal detection speed enables the timeout window.
    expect(controller.formats, contains(BarcodeFormat.qrCode));
    expect(controller.detectionSpeed, DetectionSpeed.normal);
    expect(controller.detectionTimeoutMs, 1000);
  });
}
