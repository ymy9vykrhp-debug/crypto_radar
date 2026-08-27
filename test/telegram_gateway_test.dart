import 'dart:convert';

import 'package:crypto_radar/models/integration_models.dart';
import 'package:crypto_radar/services/notifications/telegram_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Telegram relay gateway', () {
    test('disabled config performs no network request', () async {
      int requests = 0;
      final MockClient client = MockClient((http.Request request) async {
        requests++;
        return http.Response('{}', 500);
      });
      final HttpTelegramRelayGateway gateway = HttpTelegramRelayGateway(client);

      final IntegrationStatus status = await gateway.check(
        const TelegramRelayConfig(),
      );

      expect(status.state, IntegrationConnectionState.disabled);
      expect(requests, 0);
      client.close();
    });

    test(
      'health and test delivery use relay without bot credentials',
      () async {
        final List<http.Request> requests = <http.Request>[];
        final MockClient client = MockClient((http.Request request) async {
          requests.add(request);
          if (request.url.path == '/health') {
            return http.Response(
              jsonEncode(<String, Object?>{'ok': true, 'configured': true}),
              200,
            );
          }
          if (request.url.path == '/v1/telegram/messages') {
            return http.Response(
              jsonEncode(<String, Object?>{'ok': true}),
              200,
            );
          }
          return http.Response('{}', 404);
        });
        final HttpTelegramRelayGateway gateway = HttpTelegramRelayGateway(
          client,
        );
        const TelegramRelayConfig config = TelegramRelayConfig(
          enabled: true,
          baseUrl: 'http://127.0.0.1:8787',
        );

        final IntegrationStatus status = await gateway.check(config);
        await gateway.sendTest(config);

        expect(status.state, IntegrationConnectionState.connected);
        expect(requests, hasLength(2));
        expect(requests.last.body, isNot(contains('bot_token')));
        expect(requests.last.url.host, '127.0.0.1');
        client.close();
      },
    );
  });
}
