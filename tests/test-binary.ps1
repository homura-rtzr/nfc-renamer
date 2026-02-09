<#
.SYNOPSIS
    Integration tests for NfcRenamer.exe
.DESCRIPTION
    Verifies the built binary correctly normalizes file/directory names from NFD to NFC.
#>
param(
    [Parameter(Mandatory)]
    [string]$ExePath
)

$ErrorActionPreference = "Stop"

$ExePath = Resolve-Path $ExePath

if (-not (Test-Path $ExePath)) {
    Write-Host "ERROR: Binary not found at $ExePath" -ForegroundColor Red
    exit 1
}

$testDir = Join-Path $PSScriptRoot "workspace"
$passed = 0
$failed = 0

function Assert-True($name, $condition) {
    if ($condition) {
        Write-Host "  PASS: $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: $name" -ForegroundColor Red
        $script:failed++
    }
}

function Reset-Workspace {
    if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
    New-Item $testDir -ItemType Directory | Out-Null
}

# Helper: run the exe and wait for it to fully exit (WinExe is not waited on by & operator)
function Invoke-Exe {
    param([string[]]$arguments)
    $p = Start-Process -FilePath $ExePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    return $p.ExitCode
}

# --- Test 1: Single NFD file renamed to NFC ---
Write-Host "Test 1: Single file NFD -> NFC"
Reset-Workspace

# Korean "가" in NFD (Jamo: ᄀ U+1100 + ᅡ U+1161)
$nfdName = "$([char]0x1100)$([char]0x1161).txt"
# Korean "가" in NFC (U+AC00)
$nfcName = "$([char]0xAC00).txt"

$nfdPath = Join-Path $testDir $nfdName
New-Item $nfdPath -ItemType File | Out-Null

Invoke-Exe "`"$nfdPath`""

$nfcPath = Join-Path $testDir $nfcName
Assert-True "NFD file renamed to NFC" (Test-Path $nfcPath)
Assert-True "Original NFD file no longer exists" (-not (Test-Path $nfdPath))

# --- Test 2: Already NFC file stays unchanged ---
Write-Host "Test 2: NFC file unchanged"
Reset-Workspace

$nfcFile = Join-Path $testDir "already-nfc.txt"
New-Item $nfcFile -ItemType File -Value "test content" | Out-Null

Invoke-Exe "`"$nfcFile`""

Assert-True "NFC file still exists" (Test-Path $nfcFile)
Assert-True "Content preserved" ((Get-Content $nfcFile -Raw) -match "test content")

# --- Test 3: Recursive directory normalization ---
Write-Host "Test 3: Recursive directory"
Reset-Workspace

# Directory: "가dir" in NFD
$nfdDirName = "$([char]0x1100)$([char]0x1161)dir"
$nfcDirName = "$([char]0xAC00)dir"
$nfdDirPath = Join-Path $testDir $nfdDirName
New-Item $nfdDirPath -ItemType Directory | Out-Null

# Child file: "나.txt" in NFD (ᄂ U+1102 + ᅡ U+1161)
$nfdChildName = "$([char]0x1102)$([char]0x1161).txt"
$nfcChildName = "$([char]0xB098).txt"
New-Item (Join-Path $nfdDirPath $nfdChildName) -ItemType File | Out-Null

Invoke-Exe "-r", "`"$nfdDirPath`""

$nfcDirPath = Join-Path $testDir $nfcDirName
Assert-True "NFD directory renamed to NFC" (Test-Path $nfcDirPath)
Assert-True "NFD child file renamed to NFC" (Test-Path (Join-Path $nfcDirPath $nfcChildName))

# --- Test 4: Name collision resolved with suffix ---
Write-Host "Test 4: Name collision"
Reset-Workspace

# Create NFC file first
$nfcCollision = Join-Path $testDir "$([char]0xAC00)collision.txt"
New-Item $nfcCollision -ItemType File | Out-Null

# Create NFD file that normalizes to the same NFC name
$nfdCollision = Join-Path $testDir "$([char]0x1100)$([char]0x1161)collision.txt"
New-Item $nfdCollision -ItemType File | Out-Null

Invoke-Exe "`"$nfdCollision`""

$suffixedPath = Join-Path $testDir "$([char]0xAC00)collision (1).txt"
Assert-True "Original NFC file still exists" (Test-Path $nfcCollision)
Assert-True "Collision resolved with (1) suffix" (Test-Path $suffixedPath)

# --- Test 5: Non-existent path is handled gracefully ---
Write-Host "Test 5: Non-existent path"

$exitCode = Invoke-Exe "`"C:\nonexistent\path\file.txt`""

Assert-True "Non-existent path exits with code 0" ($exitCode -eq 0)

# --- Summary ---
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }

Write-Host ""
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) { exit 1 }
