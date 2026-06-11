import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../application/recent_scans_controller.dart';
import '../application/scan_controller.dart';
import '../data/scan_models.dart';
import 'widgets/scan_result_sheet.dart';

/// Builds the scanner's controller, configured to detect QR codes specifically.
///
/// Explicit `formats` (QR only) + `DetectionSpeed.normal` make ML Kit reliably
/// surface QR codes; the default empty-format controller can be flaky. Exposed
/// as a top-level function so a test can assert the configuration without a
/// camera.
MobileScannerController buildScannerController() => MobileScannerController(
  formats: const [BarcodeFormat.qrCode],
  detectionSpeed: DetectionSpeed.normal,
  detectionTimeoutMs: 1000,
);

/// Full-screen camera QR scanner. On detecting a code it pauses scanning, runs
/// the safety check, shows [ScanResultSheet], then records the scan and resumes.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = buildScannerController();

  /// Guards against the camera firing multiple detections while a result is
  /// already being handled.
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    debugPrint('DETECTED: $raw');
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    await _controller.stop();
    if (!mounted) return;

    // Kick off the check, then open the sheet which watches its progress.
    unawaited(ref.read(scanControllerProvider.notifier).check(raw));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ScanResultSheet(),
    );

    // Record the scan (regardless of action), reset, and resume scanning.
    final result = ref.read(scanControllerProvider).valueOrNull;
    if (result != null) {
      ref.read(recentScansProvider.notifier).add(
        ScanRecord(result: result, scannedAt: DateTime.now()),
      );
    }
    ref.read(scanControllerProvider.notifier).reset();

    // Resume scanning for the next code. Always clear the guard in finally so a
    // failed start() can never permanently wedge detection.
    try {
      if (mounted) await _controller.start();
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const _ScannerOverlay(),
          _topBar(context),
          _bottomControls(),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _circleButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            const Expanded(
              flex: 6,
              child: Text(
                'Point at a QR code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleButton(
                icon: Icons.flash_on_rounded,
                onTap: () => _controller.toggleTorch(),
              ),
              const SizedBox(width: 28),
              _circleButton(
                icon: Icons.cameraswitch_rounded,
                onTap: () => _controller.switchCamera(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Dimmed surround with a clear centered window and peach corner brackets.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _BracketPainter()),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );

    // Dim everything outside the scan window.
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, scrim);

    // Peach corner brackets.
    final bracket = Paint()
      ..color = AppColors.peach
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    void corner(Offset o, Offset h, Offset v) {
      canvas.drawLine(o, o + h, bracket);
      canvas.drawLine(o, o + v, bracket);
    }

    corner(rect.topLeft, const Offset(len, 0), const Offset(0, len));
    corner(rect.topRight, const Offset(-len, 0), const Offset(0, len));
    corner(rect.bottomLeft, const Offset(len, 0), const Offset(0, -len));
    corner(rect.bottomRight, const Offset(-len, 0), const Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
