import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/crypto_universe_models.dart';
import 'bybit_service.dart';
import 'storage/local_storage_backend.dart';

class CryptoUniverseController extends ChangeNotifier {
  CryptoUniverseController({
    required this.service,
    LocalStorageBackend? storage,
  }) : storage = storage ?? createLocalStorageBackend();

  static const String _favoritesKey = 'crypto_universe_favorites_v1';
  static const String _cacheKey = 'crypto_universe_cache_v1';
  static const String _cacheTimeKey = 'crypto_universe_cache_time_v1';
  static const Duration _minimumRefreshInterval = Duration(minutes: 1);

  final BybitService service;
  final LocalStorageBackend storage;

  List<CryptoAsset> _assets = <CryptoAsset>[];
  Set<String> _favorites = <String>{'BTCUSDT', 'FARTCOINUSDT'};
  AssetCategory _category = AssetCategory.topLiquid;
  AssetSort _sort = AssetSort.turnover;
  String _query = '';
  DateTime? _updatedAt;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  List<CryptoAsset> get assets => List<CryptoAsset>.unmodifiable(_assets);
  Set<String> get favorites => Set<String>.unmodifiable(_favorites);
  AssetCategory get category => _category;
  AssetSort get sort => _sort;
  String get query => _query;
  DateTime? get updatedAt => _updatedAt;
  bool get loading => _loading;
  String? get error => _error;
  bool get initialized => _initialized;

  List<CryptoAsset> get visibleAssets {
    List<CryptoAsset> result = CryptoUniverseRules.selectCategory(
      assets: _assets,
      category: _category,
      favorites: _favorites,
    );
    final String normalizedQuery = _query.trim().toUpperCase();
    if (normalizedQuery.isNotEmpty) {
      result = result
          .where(
            (CryptoAsset asset) =>
                asset.symbol.contains(normalizedQuery) ||
                asset.baseCoin.contains(normalizedQuery),
          )
          .toList(growable: false);
    }
    return CryptoUniverseRules.sortAssets(result, _sort);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _restoreFavorites();
    await _restoreCache();
    _initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    if (!force &&
        _assets.isNotEmpty &&
        _updatedAt != null &&
        DateTime.now().difference(_updatedAt!) < _minimumRefreshInterval) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final List<CryptoAsset> loaded = await service.loadCryptoUniverse();
      _assets = loaded;
      _updatedAt = DateTime.now();
      await _saveCache();
    } on Object catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategory(AssetCategory value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  void setSort(AssetSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  bool isFavorite(String symbol) =>
      _favorites.contains(normalizeCryptoSymbol(symbol));

  Future<void> toggleFavorite(String symbol) async {
    final String normalized = normalizeCryptoSymbol(symbol);
    if (normalized.isEmpty) return;
    if (!_favorites.remove(normalized)) _favorites.add(normalized);
    notifyListeners();
    await storage.write(_favoritesKey, jsonEncode(_favorites.toList()..sort()));
  }

  Future<void> _restoreFavorites() async {
    final String? raw = await storage.read(_favoritesKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        _favorites = decoded
            .map<String>((dynamic value) => normalizeCryptoSymbol('$value'))
            .where((String value) => value.isNotEmpty)
            .toSet();
      }
    } on Object {
      // Keep safe defaults when local data is corrupted.
    }
  }

  Future<void> _restoreCache() async {
    final String? raw = await storage.read(_cacheKey);
    final String? rawTime = await storage.read(_cacheTimeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        _assets = decoded
            .whereType<Map<String, dynamic>>()
            .map<CryptoAsset>(CryptoAsset.fromJson)
            .where((CryptoAsset asset) => asset.isTradingUsdtPerpetual)
            .toList(growable: false);
      }
      final int milliseconds = int.tryParse(rawTime ?? '') ?? 0;
      if (milliseconds > 0) {
        _updatedAt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    } on Object {
      _assets = <CryptoAsset>[];
      _updatedAt = null;
    }
  }

  Future<void> _saveCache() async {
    await storage.write(
      _cacheKey,
      jsonEncode(
        _assets
            .map<Map<String, Object?>>((CryptoAsset asset) => asset.toJson())
            .toList(),
      ),
    );
    await storage.write(
      _cacheTimeKey,
      _updatedAt!.millisecondsSinceEpoch.toString(),
    );
  }
}
