$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

Write-Host ''
Write-Host 'Crypto Radar Telegram Setup' -ForegroundColor Cyan
Write-Host 'The token stays only in the memory of this PowerShell window.'
Write-Host ''

$secureToken = Read-Host 'Paste the NEW Bot Token from @BotFather' -AsSecureString
$tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)

try {
    $env:CRYPTO_RADAR_TELEGRAM_BOT_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    Remove-Variable secureToken -ErrorAction SilentlyContinue
    Remove-Variable tokenPointer -ErrorAction SilentlyContinue
}

if ([string]::IsNullOrWhiteSpace($env:CRYPTO_RADAR_TELEGRAM_BOT_TOKEN)) {
    throw 'Bot Token was not entered.'
}

Write-Host ''
Write-Host '1. Open your bot in Telegram.' -ForegroundColor Yellow
Write-Host '2. Press Start or send /start.' -ForegroundColor Yellow
Write-Host '3. In Crypto Radar open Integrations and click Find chat after /start.' -ForegroundColor Yellow
Write-Host '4. After CONNECTED, click Send test.' -ForegroundColor Yellow
Write-Host ''

try {
    dart run tool\telegram_relay.dart
}
finally {
    Remove-Item Env:CRYPTO_RADAR_TELEGRAM_BOT_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:CRYPTO_RADAR_TELEGRAM_CHAT_ID -ErrorAction SilentlyContinue
}
