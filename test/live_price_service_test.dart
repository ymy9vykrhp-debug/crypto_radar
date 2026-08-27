import 'dart:async';
import 'dart:convert';

import 'package:crypto_radar/models/live_market_models.dart';
import 'package:crypto_radar/services/live_price_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LivePriceService', () {
    test(
      'throttles ticker UI updates and emits one closed-candle pulse',
      () async {
        final _FakeSocket socket = _FakeSocket();
        final LivePriceService service = LivePriceService(
          socketFactory: () => socket,
          publishInterval: const Duration(milliseconds: 30),
          heartbeatInterval: const Duration(days: 1),
          reconnectBaseDelay: const Duration(milliseconds: 10),
          reconnectMaximumDelay: const Duration(milliseconds: 20),
        );

        await service.start('btc/usdt');
        await Future<void>.delayed(Duration.zero);
        expect(socket.connectedUri, LivePriceService.endpoint);
        expect(socket.sent, hasLength(1));
        final Map<String, dynamic> subscription = jsonDecode(socket.sent.first);
        expect(subscription['args'], <String>[
          'tickers.BTCUSDT',
          'kline.1.BTCUSDT',
        ]);

        socket.emit(<String, Object?>{'success': true, 'op': 'subscribe'});
        expect(service.status, LiveConnectionStatus.live);

        socket.emit(_ticker(100));
        socket.emit(_ticker(101));
        socket.emit(_ticker(102));
        expect(service.latestTick, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 45));
        expect(service.latestTick?.price, 102);

        socket.emit(_closedMinute(1700000000000));
        socket.emit(_closedMinute(1700000000000));
        expect(service.analysisRevision, 1);

        await service.stop();
        expect(socket.closed, isTrue);
        expect(service.status, LiveConnectionStatus.offline);
        expect(service.running, isFalse);
        service.dispose();
      },
    );

    test('reconnects after an unexpected disconnect', () async {
      final List<_FakeSocket> sockets = <_FakeSocket>[];
      final LivePriceService service = LivePriceService(
        socketFactory: () {
          final _FakeSocket socket = _FakeSocket();
          sockets.add(socket);
          return socket;
        },
        publishInterval: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(days: 1),
        reconnectBaseDelay: const Duration(milliseconds: 5),
        reconnectMaximumDelay: const Duration(milliseconds: 10),
      );

      await service.start('ETHUSDT');
      await Future<void>.delayed(Duration.zero);
      expect(sockets, hasLength(1));
      await sockets.first.endUnexpectedly();
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(sockets.length, greaterThanOrEqualTo(2));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      sockets.last.emit(<String, Object?>{'success': true, 'op': 'subscribe'});
      expect(service.status, LiveConnectionStatus.live);

      await service.stop();
      service.dispose();
    });
  });
}

Map<String, Object?> _ticker(double price) => <String, Object?>{
  'topic': 'tickers.BTCUSDT',
  'ts': 1700000000100,
  'data': <String, Object?>{'symbol': 'BTCUSDT', 'lastPrice': '$price'},
};

Map<String, Object?> _closedMinute(int start) => <String, Object?>{
  'topic': 'kline.1.BTCUSDT',
  'data': <Object?>[
    <String, Object?>{'start': start, 'confirm': true},
  ],
};

class _FakeSocket implements LiveSocketClient {
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast(sync: true);
  final List<String> sent = <String>[];
  Uri? connectedUri;
  bool closed = false;

  @override
  Stream<Object?> get messages => _controller.stream;

  @override
  Future<void> connect(Uri uri) async {
    connectedUri = uri;
  }

  @override
  void send(String message) => sent.add(message);

  void emit(Object? message) => _controller.add(jsonEncode(message));

  Future<void> endUnexpectedly() => _controller.close();

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}
