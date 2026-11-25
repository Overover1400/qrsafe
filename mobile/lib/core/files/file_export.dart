import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves generated files and hands them to the system share sheet. Kept thin
/// and free of UI so the screens stay presentational; not unit-tested (it
/// touches platform plugins).
class FileExportService {
  const FileExportService();

  /// Writes [bytes] to [fileName] in the app documents directory and returns
  /// the file. (We use the app documents dir rather than a public Downloads
  /// folder so no extra storage permission is needed; the share sheet is how
  /// the file reaches Gallery, Files or another app.)
  Future<File> save(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the system share sheet for a file already on disk.
  ///
  /// Sharing the real path rather than in-memory bytes keeps the file name and
  /// extension intact, so the receiving app sees a `.png` / `.svg` / `.pdf`
  /// instead of an unnamed blob it may refuse to open.
  Future<void> shareFile(File file, {String? mimeType}) async {
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)]);
  }

  /// Saves [bytes] and immediately offers them in the share sheet.
  Future<File> saveAndShare(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
  }) async {
    final file = await save(bytes, fileName);
    await shareFile(file, mimeType: mimeType);
    return file;
  }
}
