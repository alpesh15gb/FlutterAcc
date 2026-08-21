import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart';

Future<bool> saveDownloadedFile(Uint8List bytes, String fileName) =>
    saveDownloadedFileImpl(bytes, fileName);
