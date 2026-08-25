import 'dart:convert';
import 'dart:io';

import 'local_storage_base.dart';

LocalStorageBackend createLocalStorageBackend() => _JsonFileStorage();

class _JsonFileStorage implements LocalStorageBackend {
  _JsonFileStorage() : _file = _resolveFile();

  final File _file;

  static File _resolveFile() {
    final String basePath =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File(
      '$basePath${Platform.pathSeparator}CryptoRadar'
      '${Platform.pathSeparator}journal_store.json',
    );
  }

  @override
  Future<String?> read(String key) async {
    final Map<String, dynamic> values = await _readAll();
    return values[key]?.toString();
  }

  @override
  Future<void> write(String key, String value) async {
    final Map<String, dynamic> values = await _readAll();
    values[key] = value;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(values), flush: true);
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (!await _file.exists()) {
      return <String, dynamic>{};
    }
    try {
      final Object? decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }
}
