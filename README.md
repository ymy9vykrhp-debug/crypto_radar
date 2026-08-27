# Crypto Radar

Local Flutter market-analysis application for Bybit USDT perpetual instruments.
It includes the shared Signal Engine, Journal, Trade Tracker, backtest,
interactive chart, Smart Position Calculator, safe Telegram notifications and a
contextual Help Center.

## Run the application

Open PowerShell:

```powershell
cd C:\flutter_projects\crypto_radar
flutter run -d chrome
```

The application is **MONITOR ONLY**. Paper and Bybit Demo are not configured,
and Bybit LIVE execution is hard blocked.

## Optional Telegram relay

Telegram secrets must never be entered into the Flutter web interface or saved
in this repository. Start the local relay in a second PowerShell window:

```powershell
cd C:\flutter_projects\crypto_radar
$env:CRYPTO_RADAR_TELEGRAM_BOT_TOKEN = 'YOUR_BOT_TOKEN'
$env:CRYPTO_RADAR_TELEGRAM_CHAT_ID = 'YOUR_CHAT_ID'
dart run tool\telegram_relay.dart
```

Then open **Integrations → Official Crypto Radar Telegram**, enable delivery,
keep `http://127.0.0.1:8787`, and use **Save & check** followed by **Send test**.

Closing that PowerShell window removes the relay process. The environment
variables are not persisted by the application.

## Verification

```powershell
flutter analyze
flutter test
```
