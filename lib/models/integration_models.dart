class TelegramRelayConfig {
  const TelegramRelayConfig({
    this.enabled = false,
    this.baseUrl = 'http://127.0.0.1:8787',
  });

  final bool enabled;
  final String baseUrl;

  bool get hasValidUrl {
    final Uri? uri = Uri.tryParse(baseUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  TelegramRelayConfig copyWith({bool? enabled, String? baseUrl}) =>
      TelegramRelayConfig(
        enabled: enabled ?? this.enabled,
        baseUrl: baseUrl ?? this.baseUrl,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'baseUrl': baseUrl,
  };

  factory TelegramRelayConfig.fromJson(Map<String, dynamic> json) =>
      TelegramRelayConfig(
        enabled: json['enabled'] == true,
        baseUrl: json['baseUrl']?.toString().trim().isNotEmpty == true
            ? json['baseUrl'].toString().trim()
            : 'http://127.0.0.1:8787',
      );
}

enum IntegrationConnectionState {
  disabled,
  checking,
  connected,
  notConfigured,
  unavailable,
}

class IntegrationStatus {
  const IntegrationStatus({
    required this.state,
    required this.message,
    this.checkedAt,
  });

  final IntegrationConnectionState state;
  final String message;
  final DateTime? checkedAt;
}
