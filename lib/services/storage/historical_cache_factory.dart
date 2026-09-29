import 'historical_cache_factory_io.dart'
    if (dart.library.js_interop) 'historical_cache_factory_web.dart'
    as platform;

import 'package:idb_shim/idb.dart';

IdbFactory historicalIdbFactory() => platform.historicalIdbFactory();

String historicalDatabaseName() => platform.historicalDatabaseName();
