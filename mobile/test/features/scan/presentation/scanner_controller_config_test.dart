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

  test('scanner controller detects QR codes and common barcodes', () {
    final controller = buildScannerController();
    addTearDown(controller.dispose);

    // Explicit formats make detection reliable (an empty format list can be
    // flaky); normal detection speed enables the timeout window.
    expect(controller.formats, contains(BarcodeFormat.qrCode));

    // The store listing says "barcode scanner", so these must stay listed:
    // a format missing here is simply never seen by the camera.
    for (final f in [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
    ]) {
      expect(controller.formats, contains(f), reason: '\$f must be scannable');
    }
    expect(controller.formats, isNot(contains(BarcodeFormat.all)),
        reason: 'all-formats is slower than naming the ones we support');
    expect(controller.detectionSpeed, DetectionSpeed.normal);
    expect(controller.detectionTimeoutMs, 1000);

    // The screen asks for the camera permission and starts the camera itself.
    // With autoStart the first start() races the permission dialog, fails, and
    // never retries once the permission is granted.
    expect(controller.autoStart, isFalse);
  });
}
