# uninstall.ps1
# NfcRenamer 제거 스크립트
# - 컨텍스트 메뉴 레지스트리 키 삭제
# - %LOCALAPPDATA%\NfcRenamer\ 디렉토리 삭제
#
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "Stop"

$installDir = Join-Path $env:LOCALAPPDATA "NfcRenamer"

# ── 1. Check running process ────────────────────────────
$running = Get-Process -Name "NfcRenamer" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Warning: NfcRenamer is currently running. Close it before uninstalling." -ForegroundColor Yellow
    $answer = Read-Host "Continue anyway? (y/N)"
    if ($answer -ne "y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# ── 2. Remove registry keys ─────────────────────────────
Write-Host "[1/2] Removing context menus..." -ForegroundColor Cyan

$keys = @(
    "HKCU:\Software\Classes\*\shell\NfcRenamer",
    "HKCU:\Software\Classes\Directory\shell\NfcRenamer",
    "HKCU:\Software\Classes\Directory\shell\NfcRenamerRecursive"
)

foreach ($key in $keys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "  Removed: $key"
    }
}

# ── 3. Remove files ─────────────────────────────────────
Write-Host "[2/2] Removing files..." -ForegroundColor Cyan

if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
    Write-Host "  Removed: $installDir"
} else {
    Write-Host "  Directory not found: $installDir (already removed)"
}

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
