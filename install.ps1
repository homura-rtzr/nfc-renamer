# install.ps1
# NfcRenamer 설치 스크립트
# - dotnet publish로 빌드
# - %LOCALAPPDATA%\NfcRenamer\에 복사
# - HKCU 레지스트리에 컨텍스트 메뉴 등록 (관리자 불필요)
#
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$installDir = Join-Path $env:LOCALAPPDATA "NfcRenamer"
$exeName = "NfcRenamer.exe"
$projectDir = $PSScriptRoot

# ── 1. Build or locate exe ────────────────────────────────
$prebuiltExe = Join-Path $projectDir $exeName

if (Test-Path $prebuiltExe) {
    # Release ZIP: pre-built exe exists next to this script
    Write-Host "[1/3] Using pre-built $exeName ..." -ForegroundColor Cyan
    $sourceDir = $projectDir
} else {
    # Development: build from source
    Write-Host "[1/3] Building..." -ForegroundColor Cyan
    dotnet publish "$projectDir" -c Release -r win-x64 -o "$projectDir\publish" --nologo -v quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed." -ForegroundColor Red
        exit 1
    }
    $sourceDir = "$projectDir\publish"
}

# ── 2. Copy files ────────────────────────────────────────
Write-Host "[2/3] Installing to $installDir ..." -ForegroundColor Cyan

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Copy-Item -Path "$sourceDir\$exeName" -Destination $installDir -Force

$exePath = Join-Path $installDir $exeName
if (!(Test-Path $exePath)) {
    Write-Host "Error: $exePath not found after install." -ForegroundColor Red
    exit 1
}

# ── 3. Registry ──────────────────────────────────────────
# Note: Use .NET Registry API instead of PowerShell cmdlets because
# the HKCU:\Software\Classes\* path causes PowerShell to expand the
# wildcard, enumerating thousands of keys and hanging.
Write-Host "[3/3] Registering context menus..." -ForegroundColor Cyan

# 3a. File context menu: NFC 정규화
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\*\shell\NfcRenamer\command')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\*\shell\NfcRenamer', $true)
$key.SetValue('', 'NFC 정규화')
$key.SetValue('Icon', "`"$exePath`",0")
$key.SetValue('MultiSelectModel', 'Player')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\*\shell\NfcRenamer\command', $true)
$key.SetValue('', "`"$exePath`" `"%1`"")
$key.Close()

# 3b. Directory context menu: NFC 정규화
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\Directory\shell\NfcRenamer\command')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Directory\shell\NfcRenamer', $true)
$key.SetValue('', 'NFC 정규화')
$key.SetValue('Icon', "`"$exePath`",0")
$key.SetValue('MultiSelectModel', 'Player')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Directory\shell\NfcRenamer\command', $true)
$key.SetValue('', "`"$exePath`" `"%1`"")
$key.Close()

# 3c. Directory context menu: NFC 정규화 (하위 포함)
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\Directory\shell\NfcRenamerRecursive\command')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Directory\shell\NfcRenamerRecursive', $true)
$key.SetValue('', 'NFC 정규화 (하위 포함)')
$key.SetValue('Icon', "`"$exePath`",0")
$key.SetValue('MultiSelectModel', 'Player')
$key.Close()
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Directory\shell\NfcRenamerRecursive\command', $true)
$key.SetValue('', "`"$exePath`" /r `"%1`"")
$key.Close()

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "  Location: $installDir"
Write-Host "  Right-click files/folders to see 'NFC 정규화' menu."
Write-Host "  (Windows 11: 'Show more options' first)"
