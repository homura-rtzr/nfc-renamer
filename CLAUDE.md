# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NfcRenamer is a Windows utility that normalizes file and directory names to Unicode NFC form (Normalization Form C). It integrates with Windows Explorer context menus as a silent, queue-driven background process—the WinForms Form1 files are unused placeholders.

## Build Commands

```bash
dotnet build          # Build the project
dotnet run            # Build and run
dotnet publish        # Create publishable output
```

Target framework: `net9.0-windows` (requires .NET 9 SDK with Windows desktop workload). No external NuGet dependencies.

## CI/CD

Two GitHub Actions workflows in `.github/workflows/`:

- **build.yml**: Runs on push/PR to main. Builds the project and runs integration tests (`tests/test-binary.ps1`).
- **release.yml**: Runs when a GitHub Release is published. Builds self-contained binaries for `win-x64` and `win-arm64`, packages each as a ZIP, and uploads to the Release.

### Integration Tests

`tests/test-binary.ps1` runs the built exe against real files on the filesystem:

1. Single file NFD → NFC renaming
2. Already-NFC files left unchanged
3. Recursive directory normalization (`-r` flag)
4. Name collision resolved with `(1)` suffix
5. Non-existent path handled gracefully

Note: The exe is `OutputType=WinExe`, so tests use `Start-Process -Wait` instead of `&` to ensure the process completes before assertions.

## Architecture

All logic lives in **Program.cs** (~270 lines). No linting config.

### Execution Flow

1. **Enqueue** (`EnqueueInvocation`): Command-line args are parsed into `Job` records and base64-encoded into a persistent queue file (`%LOCALAPPDATA%/NfcRenamer/queue.txt`). Retry logic handles concurrent file access from multiple Explorer invocations.
2. **Mutex gate** (`Local\NfcRenamer_Mutex_v1`): The first instance acquires the mutex, waits briefly for other instances to finish enqueuing, then processes all jobs. Later instances exit after enqueuing.
3. **Dequeue** (`DequeueAllJobsDistinct`): Reads and deduplicates jobs from the queue file, then clears it.
4. **Process** (`ProcessJob` → `NormalizeDirectoryRecursive` / `NormalizeSingle`): Renames files/directories to NFC-normalized names. Recursive processing works deepest-first to avoid path invalidation. `EnsureUniqueName` handles collisions with `(1)`, `(2)` suffixes.

### Key Design Decisions

- **Queue file + mutex pattern**: Consolidates multiple simultaneous Explorer context-menu invocations (e.g., multi-select) into a single processing run.
- **Base64-encoded queue entries**: Safely handles paths with special characters and newlines.
- **CLI flags**: `-r` / `/r` for recursive directory mode; all other args are paths.
- **Logging**: Appends to `%LOCALAPPDATA%/NfcRenamer/log.txt` with timestamps; failures are silently swallowed.
- **Self-contained publish**: Release builds bundle the .NET runtime (~150MB+) since Windows does not ship with .NET 9. `UseWindowsForms` is enabled for the WinExe placeholder but no WinForms APIs are actually used.

## Installation

`install.ps1` builds, copies to `%LOCALAPPDATA%\NfcRenamer\`, and registers Explorer context menus via HKCU registry. `uninstall.ps1` reverses this. The exe icon (`app.ico`) is embedded and also used as the context menu icon.
