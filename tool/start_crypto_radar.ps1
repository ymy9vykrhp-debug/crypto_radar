$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

Write-Host ''
Write-Host 'Crypto Radar' -ForegroundColor Cyan
Write-Host 'Проверяю зависимости и запускаю приложение в Chrome.'
Write-Host ''

flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw 'Не удалось подготовить зависимости Flutter.'
}

flutter run -d chrome
