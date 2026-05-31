import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';

/// Renders [data] as a QR code on a white square, in the given foreground
/// [color]. Shared by the generator live preview and the code detail screen so
/// both render identically. Shows a placeholder when [data] is empty (the live
/// preview before the user has typed anything).
class QrView extends StatelessWidget {
  const QrView({
    super.key,
    required this.data,
    this.color = const Color(0xFF3D2E1F),
    this.size = 220,
  });

  final String data;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _Placeholder(size: size);
    }
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: color,
      ),
      errorStateBuilder: (context, error) => _Placeholder(size: size),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(Icons.qr_code_2_rounded, size: size * 0.5, color: c.brownTint),
      ),
    );
  }
}
