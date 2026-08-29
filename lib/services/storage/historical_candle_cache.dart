import 'package:idb_shim/idb.dart';

import 'historical_cache_factory.dart';

abstract interface class HistoricalCandleCache {
  Future<Map<String, dynamic>?> read(String key);

  Future<void> write(String key, Map<String, dynamic> value);
}

HistoricalCandleCache createHistoricalCandleCache() => IdbHistoricalCandleCache(
  factory: historicalIdbFactory(),
  databaseName: historicalDatabaseName(),
);

class IdbHistoricalCandleCache implements HistoricalCandleCache {
  IdbHistoricalCandleCache({
    required IdbFactory factory,
    required String databaseName,
  }) : this._(factory, databaseName);

  IdbHistoricalCandleCache._(this._factory, this._databaseName);

  static const String _storeName = 'candle_sets';
  final IdbFactory _factory;
  final String _databaseName;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> _open() async {
    final Database? current = _database;
    if (current != null) return current;
    final Future<Database>? pending = _opening;
    if (pending != null) return pending;
    final Future<Database> opening = _factory.open(
      _databaseName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        if (!event.database.objectStoreNames.contains(_storeName)) {
          event.database.createObjectStore(_storeName);
        }
      },
    );
    _opening = opening;
    try {
      final Database opened = await opening;
      _database = opened;
      return opened;
    } finally {
      _opening = null;
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final Database database = await _open();
    final Transaction transaction = database.transaction(
      _storeName,
      idbModeReadOnly,
    );
    final Object? raw = await transaction
        .objectStore(_storeName)
        .getObject(key);
    await transaction.completed;
    if (raw is! Map) return null;
    return raw.map<String, dynamic>(
      (Object? mapKey, Object? value) =>
          MapEntry<String, dynamic>(mapKey.toString(), value),
    );
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final Database database = await _open();
    final Transaction transaction = database.transaction(
      _storeName,
      idbModeReadWrite,
    );
    await transaction.objectStore(_storeName).put(value, key);
    await transaction.completed;
  }
}
