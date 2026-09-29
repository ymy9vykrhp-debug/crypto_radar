import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/live_price_service.dart';
import 'package:crypto_radar/services/manual_assistant_controller.dart';
import 'package:crypto_radar/services/market_data_provider.dart';
import 'package:crypto_radar/services/storage/local_storage_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LIVE pause stops stream and scheduled requests; manual refresh and resume work', (tester) async {
    final provider = _Provider();
    final live = _Live();
    final controller = ManualAssistantController(provider: provider, live: live, storage: _Storage());
    await controller.initialize();
    await tester.pump();
    expect(live.running, isTrue);
    expect(provider.requests, 4);
    await tester.pump(const Duration(seconds: 16));
    expect(provider.requests, 8);
    await controller.setLiveEnabled(false);
    expect(live.running, isFalse);
    await tester.pump(const Duration(seconds: 31));
    expect(provider.requests, 8);
    await controller.refresh();
    expect(provider.requests, 12);
    expect(controller.liveEnabled, isFalse);
    await controller.setLiveEnabled(true);
    await tester.pump();
    expect(live.running, isTrue);
    expect(provider.requests, 16);
    await tester.pump(const Duration(seconds: 16));
    expect(provider.requests, 20);
    controller.dispose();
  });
}

class _Provider implements MarketDataProvider {
  int requests = 0;
  @override
  Future<MarketSnapshot> load(String symbol) async {
    requests++;
    throw StateError('Offline fixture');
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Live extends LivePriceService {
  bool _running = false;
  @override
  bool get running => _running;
  @override
  Future<void> start(String symbol) async { _running = true; }
  @override
  Future<void> stop() async { _running = false; }
}

class _Storage implements LocalStorageBackend {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}
