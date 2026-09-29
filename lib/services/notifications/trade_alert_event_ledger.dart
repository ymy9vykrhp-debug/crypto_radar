import 'dart:convert';

import '../storage/local_storage_backend.dart';

/// Small local ledger used to make outbound alert events idempotent across
/// refreshes and application restarts. It contains event IDs only, no tokens,
/// chat IDs, prices, or account information.
class TradeAlertEventLedger {
  TradeAlertEventLedger({LocalStorageBackend? storage})
    : _storage = storage ?? createLocalStorageBackend();

  static const String _storageKey = 'trade_alert_delivered_events_v1';
  static const int _maximumEntries = 2000;

  final LocalStorageBackend _storage;
  final Map<String, DateTime> _delivered = <String, DateTime>{};
  Future<void> _writeQueue = Future<void>.value();
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final String? raw = await _storage.read(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;
      for (final Object? item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final String id = item['id']?.toString().trim() ?? '';
        final DateTime? deliveredAt = DateTime.tryParse(
          item['deliveredAt']?.toString() ?? '',
        );
        if (id.isNotEmpty && deliveredAt != null) {
          _delivered[id] = deliveredAt.toUtc();
        }
      }
      _trim();
    } on Object {
      // A corrupt local ledger must not prevent market monitoring.
      _delivered.clear();
    }
  }

  bool contains(String eventId) => _delivered.containsKey(eventId);

  Future<void> markDelivered(String eventId, DateTime deliveredAt) async {
    if (eventId.isEmpty) return;
    _delivered[eventId] = deliveredAt.toUtc();
    _trim();
    final String payload = jsonEncode(
      _delivered.entries
          .map<Map<String, String>>(
            (MapEntry<String, DateTime> entry) => <String, String>{
              'id': entry.key,
              'deliveredAt': entry.value.toIso8601String(),
            },
          )
          .toList(growable: false),
    );
    _writeQueue = _writeQueue.then<void>(
      (_) => _storage.write(_storageKey, payload),
    );
    await _writeQueue;
  }

  void _trim() {
    if (_delivered.length <= _maximumEntries) return;
    final List<MapEntry<String, DateTime>> ordered = _delivered.entries.toList()
      ..sort(
        (MapEntry<String, DateTime> first, MapEntry<String, DateTime> second) =>
            second.value.compareTo(first.value),
      );
    final Set<String> retained = ordered
        .take(_maximumEntries)
        .map<String>((MapEntry<String, DateTime> entry) => entry.key)
        .toSet();
    _delivered.removeWhere(
      (String eventId, DateTime _) => !retained.contains(eventId),
    );
  }
}
