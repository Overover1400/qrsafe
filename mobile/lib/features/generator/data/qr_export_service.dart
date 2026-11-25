import '../../../core/files/file_export.dart';

export '../../../core/files/file_export.dart';

/// The generator's name for the shared file exporter. Kept as an alias so the
/// download sheet reads in its own terms while document scanning and QR export
/// share one implementation.
typedef QrExportService = FileExportService;
