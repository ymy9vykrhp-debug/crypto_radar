$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

Write-Host ''
Write-Host 'Crypto Radar Telegram Setup' -ForegroundColor Cyan
Write-Host 'Токен останется только в памяти этого окна PowerShell.'
Write-Host ''

$secureToken = Read-Host 'Вставьте Bot Token от @BotFather' -AsSecureString
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
    throw 'Bot Token не введён.'
}

Write-Host ''
Write-Host '1. Откройте созданного бота в Telegram.' -ForegroundColor Yellow
Write-Host '2. Нажмите Start или отправьте /start.' -ForegroundColor Yellow
Write-Host '3. В Crypto Radar откройте Интеграции и нажмите «Найти чат после /start».' -ForegroundColor Yellow
Write-Host '4. После статуса CONNECTED нажмите «Отправить тест».' -ForegroundColor Yellow
Write-Host ''

try {
    dart run tool\telegram_relay.dart
}
finally {
    Remove-Item Env:CRYPTO_RADAR_TELEGRAM_BOT_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:CRYPTO_RADAR_TELEGRAM_CHAT_ID -ErrorAction SilentlyContinue
}
