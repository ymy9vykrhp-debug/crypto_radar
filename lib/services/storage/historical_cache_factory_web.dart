import 'package:idb_shim/idb_browser.dart';

IdbFactory historicalIdbFactory() => idbFactoryBrowser;

String historicalDatabaseName() => 'crypto_radar_market_history';
