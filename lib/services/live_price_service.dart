import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/crypto_universe_models.dart';
import '../models/live_market_models.dart';

abstract interface class LiveSocketClient {
  Stream<Object?> get messages;

  Future<void> connect(Uri uri);

  void send(String message);

  Future<void> close();
}

class WebSocketLiveSocketClient implements LiveSocketClient {
  WebSocketChannel? _channel;

  @override
  Stream<Object?> get messages => _channel!.stream;

  @override
  Future<void> connect(Uri uri) async {
    final WebSocketChannel channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready.timeout(const Duration(seconds: 12));
  }

  @override
  void send(String message) => _channel?.sink.add(message);

  @override
  Future<void> close() async {
    final WebSocketChannel? channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }
}

typedef LiveSocketFactory = LiveSocketClient Function();

/// Public market-data-only Bybit WebSocket feed.
///
/// Incoming ticker messages may arrive every 100 ms. They are retained in
/// memory and published to the Flutter UI at [publishInterval] so the widget
/// tree is never rebuilt for every exchange tick.
class LivePriceService extends ChangeNotifier {
  LivePriceService({
    LiveSocketFactory? socketFactory,
    this.publishInterval = const Duration(milliseconds: 350),
    this.heartbeatInterval = const Duration(seconds: 20),
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.reconnectMaximumDelay = const Duration(seconds: 15),
  }) : _socketFactory = socketFactory ?? (() => WebSocketLiveSocketClient());

  static final Uri endpoint = Uri.parse(
    'wss://stream.bybit.com/v5/public/linear',
  );

  final LiveSocketFactory _socketFactory;
  final Duration publishInterval;
  final Duration heartbeatInterval;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaximumDelay;

  LiveConnectionStatus _status = LiveConnectionStatus.offline;
  LivePriceTick? _latestTick;
  LivePriceTick? _pendingTick;
  LiveSocketClient? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _publishTimer;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _symbol;
  int _session = 0;
  int _reconnectAttempt = 0;
  int _analysisRevision = 0;
  int? _lastClosedMinuteStart;
  bool _running = false;
  bool _disposed = false;

  LiveConnectionStatus get status => _status;
  LivePriceTick? get latestTick => _latestTick;
  String? get symbol => _symbol;
  int get analysisRevision => _analysisRevision;
  bool get running => _running;

  Future<void> start(String rawSymbol) async {
    final String normalized = normalizeCryptoSymbol(rawSymbol);
    if (normalized.isEmpty) return;
    if (_running && _symbol == normalized) return;
    await stop();
    if (_disposed) return;
    _running = true;
    _symbol = normalized;
    _reconnectAttempt = 0;
    _publishTimer = Timer.periodic(publishInterval, (_) => _publishPending());
    final int session = ++_session;
    unawaited(_connect(session));
  }

  Future<void> switchSymbol(String rawSymbol) => start(rawSymbol);

  Future<void> stop() async {
    _running = false;
    _session++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _publishTimer?.cancel();
    _publishTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final LiveSocketClient? socket = _socket;
    _socket = null;
    await socket?.close();
    _pendingTick = null;
    _latestTick = null;
    _lastClosedMinuteStart = null;
    _setStatus(LiveConnectionStatus.offline);
  }

  Future<void> _connect(int session) async {
    if (!_isCurrent(session)) return;
    _setStatus(LiveConnectionStatus.connecting);
    final LiveSocketClient socket = _socketFactory();
    _socket = socket;
    try {
      await socket.connect(endpoint);
      if (!_isCurrent(session) || _socket != socket) {
        await socket.close();
        return;
      }
      _subscription = socket.messages.listen(
        (Object? message) => _handleMessage(message, session),
        onError: (Object error, StackTrace stackTrace) =>
            _handleDisconnect(session),
        onDone: () => _handleDisconnect(session),
        cancelOnError: true,
      );
      socket.send(
        jsonEncode(<String, Object?>{
          'req_id': 'crypto-radar-$session',
          'op': 'subscribe',
          'args': <String>['tickers.${_symbol!}', 'kline.1.${_symbol!}'],
        }),
      );
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
        if (_isCurrent(session) && _socket == socket) {
          socket.send(
            jsonEncode(<String, Object?>{
              'req_id': 'heartbeat-$session',
              'op': 'ping',
            }),
          );
        }
      });
    } on Object {
      await socket.close();
      if (_socket == socket) _socket = null;
      _handleDisconnect(session);
    }
  }

  void _handleMessage(Object? rawMessage, int session) {
    if (!_isCurrent(session)) return;
    try {
      final Object? decoded = switch (rawMessage) {
        String value => jsonDecode(value),
        List<int> value => jsonDecode(utf8.decode(value)),
        _ => rawMessage,
      };
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['success'] == true && decoded['op'] == 'subscribe') {
        _reconnectAttempt = 0;
        _setStatus(LiveConnectionStatus.live);
        return;
      }
      final String topic = decoded['topic']?.toString() ?? '';
      if (topic == 'tickers.${_symbol!}') {
        _consumeTicker(decoded);
      } else if (topic == 'kline.1.${_symbol!}') {
        _consumeMinuteKline(decoded);
      }
    } on Object {
      // Ignore one malformed public packet; a later valid packet can recover.
    }
  }

  void _consumeTicker(Map<String, dynamic> message) {
    final Object? rawData = message['data'];
    final Map<String, dynamic>? data = switch (rawData) {
      Map<String, dynamic> value => value,
      List<dynamic> value
          when value.isNotEmpty && value.first is Map<String, dynamic> =>
        value.first as Map<String, dynamic>,
      _ => null,
    };
    if (data == null) return;
    final double price = double.tryParse('${data['lastPrice']}') ?? 0.0;
    if (price <= 0.0) return;
    final int timestamp = int.tryParse('${message['ts']}') ?? 0;
    _pendingTick = LivePriceTick(
      symbol: _symbol!,
      price: price,
      receivedAt: timestamp <= 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    _reconnectAttempt = 0;
    _setStatus(LiveConnectionStatus.live);
  }

  void _consumeMinuteKline(Map<String, dynamic> message) {
    final Object? rawData = message['data'];
    if (rawData is! List<dynamic>) return;
    for (final Object? item in rawData) {
      if (item is! Map<String, dynamic> || item['confirm'] != true) continue;
      final int start = int.tryParse('${item['start']}') ?? 0;
      if (start <= 0 || start == _lastClosedMinuteStart) continue;
      _lastClosedMinuteStart = start;
      _analysisRevision++;
      _notify();
    }
  }

  void _publishPending() {
    final LivePriceTick? pending = _pendingTick;
    if (pending == null ||
        (_latestTick?.price == pending.price &&
            _latestTick?.receivedAt == pending.receivedAt)) {
      return;
    }
    _latestTick = pending;
    _notify();
  }

  void _handleDisconnect(int session) {
    if (!_isCurrent(session)) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final LiveSocketClient? socket = _socket;
    _socket = null;
    unawaited(socket?.close());
    _setStatus(LiveConnectionStatus.offline);
    if (_reconnectTimer != null) return;
    final Duration delay = _reconnectDelay(_reconnectAttempt++);
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_isCurrent(session)) unawaited(_connect(session));
    });
  }

  Duration _reconnectDelay(int attempt) {
    final int factor = 1 << attempt.clamp(0, 6);
    final int milliseconds = reconnectBaseDelay.inMilliseconds * factor;
    return Duration(
      milliseconds: milliseconds.clamp(
        reconnectBaseDelay.inMilliseconds,
        reconnectMaximumDelay.inMilliseconds,
      ),
    );
  }

  bool _isCurrent(int session) =>
      !_disposed && _running && _session == session && _symbol != null;

  void _setStatus(LiveConnectionStatus value) {
    if (_status == value) return;
    _status = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _running = false;
    _session++;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _publishTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    super.dispose();
  }
}
