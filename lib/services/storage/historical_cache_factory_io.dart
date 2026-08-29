import 'dart:io';

import 'package:idb_shim/idb_io.dart';

IdbFactory historicalIdbFactory() => idbFactorySembastIo;

String historicalDatabaseName() {
  final String basePath =
      Platform.environment['LOCALAPPDATA'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final Directory directory = Directory(
    '$basePath${Platform.pathSeparator}CryptoRadar'
    '${Platform.pathSeparator}history',
  );
  if (!directory.existsSync()) directory.createSync(recursive: true);
  return '${directory.path}${Platform.pathSeparator}market_history.db';
}
