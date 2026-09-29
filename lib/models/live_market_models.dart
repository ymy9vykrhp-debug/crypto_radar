enum MarketUpdateMode { live, economy15s }

extension MarketUpdateModeText on MarketUpdateMode {
  String get label => this == MarketUpdateMode.live ? '⚡ LIVE' : '15s';
}

enum LiveConnectionStatus { live, connecting, offline }

extension LiveConnectionStatusText on LiveConnectionStatus {
  String get label {
    switch (this) {
      case LiveConnectionStatus.live:
        return 'LIVE';
      case LiveConnectionStatus.connecting:
        return 'CONNECTING';
      case LiveConnectionStatus.offline:
        return 'OFFLINE';
    }
  }
}

class LivePriceTick {
  const LivePriceTick({
    required this.symbol,
    required this.price,
    required this.receivedAt,
  });

  final String symbol;
  final double price;
  final DateTime receivedAt;
}
