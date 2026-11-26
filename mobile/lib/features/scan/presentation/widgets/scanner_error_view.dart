import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';

/// What the scanner shows instead of a camera preview when the camera will not
/// start.
///
/// mobile_scanner's own fallback is a white exclamation mark on black and
/// nothing else, which looks like the app crashed and says nothing about the
/// one thing that is almost always wrong: the camera permission was refused,
/// which a reinstall is enough to cause. This names the cause and offers the
/// two ways out.
class ScannerErrorView extends StatelessWidget {
  const ScannerErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final MobileScannerException error;

  /// Asks the controller to start again. Worth offering for every error: a
  /// refusal the user has just reversed in Settings only clears on a restart.
  final Future<void> Function() onRetry;

  bool get _isPermission =>
      error.errorCode == MobileScannerErrorCode.permissionDenied;

  String get _title {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'QRSafe needs the camera';
      case MobileScannerErrorCode.unsupported:
        return 'This phone cannot scan';
      default:
        return 'The camera did not start';
    }
  }

  String get _body {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Scanning a code means looking through the camera. Turn the '
            'camera permission on for QRSafe, then come back.';
      case MobileScannerErrorCode.unsupported:
        return 'Scanning needs a rear camera this phone does not report. You '
            'can still create codes.';
      default:
        return 'Another app may be holding the camera. Close it and try '
            'again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    // The raw message is worth keeping on screen for anything we did not
    // anticipate — without it a report is just "it shows an error".
    final details = error.errorDetails?.message;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPermission
                      ? Icons.no_photography_rounded
                      : Icons.videocam_off_rounded,
                  color: AppColors.tealMid,
                  size: 56,
                ),
                const SizedBox(height: 20),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                if (_isPermission)
                  FilledButton(
                    onPressed: openAppSettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(220, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Open settings'),
                  ),
                if (_isPermission) const SizedBox(height: 10),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealLight,
                    minimumSize: const Size(220, 44),
                  ),
                  child: const Text('Try again'),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    details,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
