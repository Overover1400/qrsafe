import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrsafe_mobile/features/scan/presentation/widgets/scanner_error_view.dart';

Widget _host(MobileScannerException error, {VoidCallback? onRetry}) {
  return MaterialApp(
    home: Scaffold(
      body: ScannerErrorView(
        error: error,
        onRetry: () async => onRetry?.call(),
      ),
    ),
  );
}

void main() {
  group('ScannerErrorView', () {
    testWidgets('a refused camera names the permission and offers settings',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const MobileScannerException(
            errorCode: MobileScannerErrorCode.permissionDenied,
          ),
        ),
      );

      expect(find.text('QRSafe needs the camera'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('any other failure skips the settings button', (tester) async {
      await tester.pumpWidget(
        _host(
          const MobileScannerException(
            errorCode: MobileScannerErrorCode.genericError,
          ),
        ),
      );

      // Settings cannot fix a camera another app is holding, so offering it
      // would send her somewhere useless.
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('The camera did not start'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the platform message is shown so a report can name it',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const MobileScannerException(
            errorCode: MobileScannerErrorCode.genericError,
            errorDetails: MobileScannerErrorDetails(
              message: 'Camera in use by another app',
            ),
          ),
        ),
      );

      expect(find.text('Camera in use by another app'), findsOneWidget);
    });

    testWidgets('Try again calls back', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          const MobileScannerException(
            errorCode: MobileScannerErrorCode.permissionDenied,
          ),
          onRetry: () => tapped++,
        ),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(tapped, 1);
    });
  });
}
