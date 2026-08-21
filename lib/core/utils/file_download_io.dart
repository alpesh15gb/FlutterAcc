import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> saveDownloadedFileImpl(Uint8List bytes, String fileName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save $fileName',
    fileName: fileName,
  );
  if (path == null) return false;
  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}
