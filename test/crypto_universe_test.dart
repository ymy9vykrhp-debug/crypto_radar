import 'dart:convert';

import 'package:crypto_radar/localization/app_strings.dart';
import 'package:crypto_radar/models/crypto_universe_models.dart';
import 'package:crypto_radar/screens/asset_explorer_screen.dart';
import 'package:crypto_radar/services/bybit_service.dart';
import 'package:crypto_radar/services/app_preferences_controller.dart';
import 'package:crypto_radar/services/crypto_universe_controller.dart';
import 'package:crypto_radar/services/storage/local_storage_backend.dart';
import 'package:crypto_radar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Dynamic Crypto Universe', () {
    test('normalizes symbols without keeping a hardcoded pair list', () {
      expect(normalizeCryptoSymbol('btc/usdt'), 'BTCUSDT');
      expect(normalizeCryptoSymbol(' eth '), 'ETHUSDT');
      expect(normalizeCryptoSymbol('FARTCOINUSDT'), 'FARTCOINUSDT');
    });

    test(
      'loads paginated public Bybit instruments and joins tickers',
      () async {
        final List<Uri> requests = <Uri>[];
        final MockClient client = MockClient((http.Request request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/instruments-info')) {
            final bool isSecondPage =
                request.url.queryParameters['cursor'] == 'page-2';
            return _ok(<String, Object?>{
              'list': isSecondPage
                  ? <Object?>[
                      _instrument('FARTCOINUSDT', 'FARTCOIN'),
                      _instrument('BTCUSDC', 'BTC', quote: 'USDC'),
                    ]
                  : <Object?>[
                      _instrument('BTCUSDT', 'BTC'),
                      _instrument(
                        'OLDUSDT',
                        'OLD',
                        contractType: 'LinearFutures',
                      ),
                    ],
              'nextPageCursor': isSecondPage ? '' : 'page-2',
            });
          }
          if (request.url.path.endsWith('/tickers')) {
            return _ok(<String, Object?>{
              'list': <Object?>[
                _ticker('BTCUSDT', price: 64000, turnover: 3000000000),
                _ticker('FARTCOINUSDT', price: 0.19, turnover: 90000000),
              ],
            });
          }
          return http.Response('not found', 404);
        });

        final List<CryptoAsset> assets = await BybitService(client)
            .loadCryptoUniverse();

        expect(assets.map((CryptoAsset asset) => asset.symbol), <String>[
          'BTCUSDT',
          'FARTCOINUSDT',
        ]);
        expect(assets.first.change24hPercent, 2.5);
        expect(assets.last.maxLeverage, 10);
        expect(
          requests.where((Uri uri) => uri.path.endsWith('/instruments-info')),
          hasLength(2),
        );
        expect(
          requests.every(
            (Uri uri) => uri.queryParameters['category'] == 'linear',
          ),
          isTrue,
        );
        client.close();
      },
    );

    test(
      'categories, sorting, search, favorites and cache work locally',
      () async {
        final _MemoryStorage storage = _MemoryStorage();
        final MockClient client = _universeClient();
        final CryptoUniverseController controller = CryptoUniverseController(
          service: BybitService(client),
          storage: storage,
        );

        await controller.initialize();
        expect(controller.assets, hasLength(3));
        expect(controller.visibleAssets.first.symbol, 'BTCUSDT');

        controller.setCategory(AssetCategory.highVolatility);
        controller.setSort(AssetSort.volatility);
        expect(controller.visibleAssets.first.symbol, 'FARTCOINUSDT');

        controller.setCategory(AssetCategory.all);
        controller.setQuery('eth');
        expect(controller.visibleAssets.single.symbol, 'ETHUSDT');

        await controller.toggleFavorite('eth/usdt');
        controller.setQuery('');
        controller.setCategory(AssetCategory.favorites);
        expect(
          controller.visibleAssets.map((CryptoAsset asset) => asset.symbol),
          containsAll(<String>['BTCUSDT', 'FARTCOINUSDT', 'ETHUSDT']),
        );

        final CryptoUniverseController restored = CryptoUniverseController(
          service: BybitService(_failingClient()),
          storage: storage,
        );
        await restored.initialize();
        expect(restored.assets, hasLength(3));
        expect(restored.isFavorite('ETHUSDT'), isTrue);

        controller.dispose();
        restored.dispose();
        client.close();
      },
    );

    testWidgets('asset row selection opens the requested symbol', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final MockClient client = _universeClient();
      final CryptoUniverseController controller = CryptoUniverseController(
        service: BybitService(client),
        storage: _MemoryStorage(),
      );
      await controller.initialize();
      String? selected;

      await tester.pumpWidget(
        AppLocalization(
          strings: const AppStrings(AppLanguage.ru),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: AssetExplorerScreen(
                controller: controller,
                selectedSymbol: 'BTCUSDT',
                onSelect: (String symbol) => selected = symbol,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Volume'), findsOneWidget);
      await tester.tap(find.text('ETHUSDT').first);
      await tester.pump();
      expect(selected, 'ETHUSDT');

      controller.dispose();
      client.close();
    });
  });
}

MockClient _universeClient() {
  return MockClient((http.Request request) async {
    if (request.url.path.endsWith('/instruments-info')) {
      return _ok(<String, Object?>{
        'list': <Object?>[
          _instrument('BTCUSDT', 'BTC'),
          _instrument('ETHUSDT', 'ETH'),
          _instrument('FARTCOINUSDT', 'FARTCOIN'),
        ],
        'nextPageCursor': '',
      });
    }
    if (request.url.path.endsWith('/tickers')) {
      return _ok(<String, Object?>{
        'list': <Object?>[
          _ticker('BTCUSDT', price: 64000, turnover: 3000000000),
          _ticker('ETHUSDT', price: 3300, turnover: 1200000000),
          _ticker(
            'FARTCOINUSDT',
            price: 0.19,
            turnover: 90000000,
            high: 0.22,
            low: 0.15,
          ),
        ],
      });
    }
    return http.Response('not found', 404);
  });
}

MockClient _failingClient() =>
    MockClient((http.Request request) async => http.Response('offline', 503));

http.Response _ok(Map<String, Object?> result) => http.Response(
  jsonEncode(<String, Object?>{'retCode': 0, 'retMsg': 'OK', 'result': result}),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> _instrument(
  String symbol,
  String baseCoin, {
  String quote = 'USDT',
  String contractType = 'LinearPerpetual',
}) => <String, Object?>{
  'symbol': symbol,
  'baseCoin': baseCoin,
  'quoteCoin': quote,
  'contractType': contractType,
  'status': 'Trading',
  'launchTime': '1700000000000',
  'leverageFilter': <String, Object?>{'maxLeverage': '10'},
};

Map<String, Object?> _ticker(
  String symbol, {
  required double price,
  required double turnover,
  double high = 1.1,
  double low = 0.9,
}) => <String, Object?>{
  'symbol': symbol,
  'lastPrice': '$price',
  'price24hPcnt': '0.025',
  'turnover24h': '$turnover',
  'volume24h': '${turnover / price}',
  'highPrice24h': '$high',
  'lowPrice24h': '$low',
};

class _MemoryStorage implements LocalStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
