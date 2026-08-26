enum AssetCategory {
  favorites,
  topLiquid,
  topAlts,
  memeCoins,
  highVolatility,
  all,
}

enum AssetSort { turnover, volume, change, volatility, price, symbol }

class CryptoAsset {
  const CryptoAsset({
    required this.symbol,
    required this.baseCoin,
    required this.quoteCoin,
    required this.contractType,
    required this.status,
    required this.lastPrice,
    required this.change24hPercent,
    required this.turnover24h,
    required this.volume24h,
    required this.high24h,
    required this.low24h,
    required this.launchTime,
    required this.maxLeverage,
  });

  final String symbol;
  final String baseCoin;
  final String quoteCoin;
  final String contractType;
  final String status;
  final double lastPrice;
  final double change24hPercent;
  final double turnover24h;
  final double volume24h;
  final double high24h;
  final double low24h;
  final DateTime? launchTime;
  final double maxLeverage;

  double get volatilityPercent {
    if (lastPrice <= 0 || high24h <= 0 || low24h <= 0) return 0;
    return (high24h - low24h) / lastPrice * 100;
  }

  bool get isTradingUsdtPerpetual =>
      status == 'Trading' &&
      quoteCoin == 'USDT' &&
      contractType == 'LinearPerpetual';

  Map<String, Object?> toJson() => <String, Object?>{
    'symbol': symbol,
    'baseCoin': baseCoin,
    'quoteCoin': quoteCoin,
    'contractType': contractType,
    'status': status,
    'lastPrice': lastPrice,
    'change24hPercent': change24hPercent,
    'turnover24h': turnover24h,
    'volume24h': volume24h,
    'high24h': high24h,
    'low24h': low24h,
    'launchTime': launchTime?.millisecondsSinceEpoch,
    'maxLeverage': maxLeverage,
  };

  factory CryptoAsset.fromJson(Map<String, dynamic> json) {
    final int launchMilliseconds = _asInt(json['launchTime']);
    return CryptoAsset(
      symbol: normalizeCryptoSymbol(json['symbol']?.toString() ?? ''),
      baseCoin: json['baseCoin']?.toString().toUpperCase() ?? '',
      quoteCoin: json['quoteCoin']?.toString().toUpperCase() ?? '',
      contractType: json['contractType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastPrice: _asDouble(json['lastPrice']),
      change24hPercent: _asDouble(json['change24hPercent']),
      turnover24h: _asDouble(json['turnover24h']),
      volume24h: _asDouble(json['volume24h']),
      high24h: _asDouble(json['high24h']),
      low24h: _asDouble(json['low24h']),
      launchTime: launchMilliseconds <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              launchMilliseconds,
              isUtc: true,
            ),
      maxLeverage: _asDouble(json['maxLeverage']),
    );
  }
}

String normalizeCryptoSymbol(String raw) {
  String value = raw.trim().toUpperCase();
  value = value.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (value.isEmpty) return '';
  if (value.endsWith('USDT')) return value;
  return '${value}USDT';
}

class CryptoUniverseRules {
  static const Set<String> _majorCoins = <String>{'BTC', 'ETH'};
  static const Set<String> _memeCoins = <String>{
    'DOGE',
    'SHIB',
    'PEPE',
    'BONK',
    'FLOKI',
    'WIF',
    'FARTCOIN',
    'PENGU',
    'TRUMP',
    'MEME',
    'BRETT',
    'MOG',
    'POPCAT',
    'NEIRO',
    'SPX',
  };

  static bool isMeme(CryptoAsset asset) =>
      _memeCoins.contains(asset.baseCoin) ||
      asset.baseCoin.contains('DOGE') ||
      asset.baseCoin.contains('MEME');

  static List<CryptoAsset> selectCategory({
    required List<CryptoAsset> assets,
    required AssetCategory category,
    required Set<String> favorites,
  }) {
    final List<CryptoAsset> liquid = List<CryptoAsset>.from(assets)
      ..sort(
        (CryptoAsset a, CryptoAsset b) =>
            b.turnover24h.compareTo(a.turnover24h),
      );
    switch (category) {
      case AssetCategory.favorites:
        return liquid
            .where((CryptoAsset asset) => favorites.contains(asset.symbol))
            .toList(growable: false);
      case AssetCategory.topLiquid:
        return liquid.take(30).toList(growable: false);
      case AssetCategory.topAlts:
        return liquid
            .where((CryptoAsset asset) => !_majorCoins.contains(asset.baseCoin))
            .take(40)
            .toList(growable: false);
      case AssetCategory.memeCoins:
        return liquid.where(isMeme).toList(growable: false);
      case AssetCategory.highVolatility:
        final List<CryptoAsset> volatile = List<CryptoAsset>.from(assets)
          ..sort(
            (CryptoAsset a, CryptoAsset b) =>
                b.volatilityPercent.compareTo(a.volatilityPercent),
          );
        return volatile.take(30).toList(growable: false);
      case AssetCategory.all:
        return liquid;
    }
  }

  static List<CryptoAsset> sortAssets(
    List<CryptoAsset> assets,
    AssetSort sort,
  ) {
    final List<CryptoAsset> result = List<CryptoAsset>.from(assets);
    switch (sort) {
      case AssetSort.turnover:
        result.sort(
          (CryptoAsset a, CryptoAsset b) =>
              b.turnover24h.compareTo(a.turnover24h),
        );
      case AssetSort.volume:
        result.sort(
          (CryptoAsset a, CryptoAsset b) => b.volume24h.compareTo(a.volume24h),
        );
      case AssetSort.change:
        result.sort(
          (CryptoAsset a, CryptoAsset b) =>
              b.change24hPercent.abs().compareTo(a.change24hPercent.abs()),
        );
      case AssetSort.volatility:
        result.sort(
          (CryptoAsset a, CryptoAsset b) =>
              b.volatilityPercent.compareTo(a.volatilityPercent),
        );
      case AssetSort.price:
        result.sort(
          (CryptoAsset a, CryptoAsset b) => b.lastPrice.compareTo(a.lastPrice),
        );
      case AssetSort.symbol:
        result.sort(
          (CryptoAsset a, CryptoAsset b) => a.symbol.compareTo(b.symbol),
        );
    }
    return result;
  }
}

double _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
