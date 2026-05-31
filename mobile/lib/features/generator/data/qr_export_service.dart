import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves and shares rendered QR PNGs. Kept thin and free of UI so the download
/// sheet stays presentational; not unit-tested (it touches platform plugins).
class QrExportService {
  const QrExportService();

  /// Writes [bytes] to a file named [fileName] in the app documents directory
  /// and returns it. (We use the app documents dir rather than a public
  /// Downloads folder so no extra storage permission is needed; "Share" is the
  /// path to get the image out to other apps.)
  Future<File> saveToDownloads(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Opens the system share sheet with the PNG [bytes] directly (no file save).
  Future<void> share(Uint8List bytes, String fileName) async {
    await Share.shareXFiles([
      XFile.fromData(bytes, name: fileName, mimeType: 'image/png'),
    ]);
  }
}
