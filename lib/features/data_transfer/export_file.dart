import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const csvMimeType = 'text/csv';
const xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// An export ready to leave the app — the same bytes either get saved
/// where the user picks or handed to another app.
class ExportFile {
  const ExportFile(this.bytes, {required this.extension, required this.mimeType});

  final List<int> bytes;
  final String extension;
  final String mimeType;

  /// "backpack-gear-2026-10-21.xlsx" — dated, so repeated exports don't
  /// overwrite each other and sort by when they were made.
  String fileName({DateTime? now}) {
    final date = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    return 'backpack-gear-$date.$extension';
  }

  /// The system "Save as" screen — pick a folder (Downloads, Drive…) and
  /// the file lands there. False if the user backed out.
  Future<bool> save() async {
    final uri = await FilePicker.saveFile(
      fileName: fileName(),
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType,
    );
    return uri != null;
  }

  /// The system share sheet — send it to Drive, mail, a messenger. It can't
  /// save to the phone itself, hence [save] alongside.
  Future<void> share() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName()));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
  }
}
