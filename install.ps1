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
    dotnet publish "$projectDir" -c Release -r win-x64 --self-contained -o "$projectDir\publish" --nologo -v quiet
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
Write-Host "[3/3] Registering context menus..." -ForegroundColor Cyan

$escapedExe = $exePath.Replace("\", "\\")

# 3a. File context menu: NFC 정규화
$keyFile = "HKCU:\Software\Classes\*\shell\NfcRenamer"
New-Item -Path "$keyFile\command" -Force | Out-Null
Set-ItemProperty -Path $keyFile -Name "(Default)" -Value "NFC 정규화"
Set-ItemProperty -Path $keyFile -Name "Icon" -Value "`"$exePath`",0"
Set-ItemProperty -Path $keyFile -Name "MultiSelectModel" -Value "Player"
Set-ItemProperty -Path "$keyFile\command" -Name "(Default)" -Value "`"$exePath`" `"%1`""

# 3b. Directory context menu: NFC 정규화
$keyDir = "HKCU:\Software\Classes\Directory\shell\NfcRenamer"
New-Item -Path "$keyDir\command" -Force | Out-Null
Set-ItemProperty -Path $keyDir -Name "(Default)" -Value "NFC 정규화"
Set-ItemProperty -Path $keyDir -Name "Icon" -Value "`"$exePath`",0"
Set-ItemProperty -Path $keyDir -Name "MultiSelectModel" -Value "Player"
Set-ItemProperty -Path "$keyDir\command" -Name "(Default)" -Value "`"$exePath`" `"%1`""

# 3c. Directory context menu: NFC 정규화 (하위 포함)
$keyDirR = "HKCU:\Software\Classes\Directory\shell\NfcRenamerRecursive"
New-Item -Path "$keyDirR\command" -Force | Out-Null
Set-ItemProperty -Path $keyDirR -Name "(Default)" -Value "NFC 정규화 (하위 포함)"
Set-ItemProperty -Path $keyDirR -Name "Icon" -Value "`"$exePath`",0"
Set-ItemProperty -Path $keyDirR -Name "MultiSelectModel" -Value "Player"
Set-ItemProperty -Path "$keyDirR\command" -Name "(Default)" -Value "`"$exePath`" /r `"%1`""

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "  Location: $installDir"
Write-Host "  Right-click files/folders to see 'NFC 정규화' menu."
Write-Host "  (Windows 11: 'Show more options' first)"
