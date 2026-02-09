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

## Architecture

All logic lives in **Program.cs** (~270 lines). There are no tests, no CI, and no linting config.

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
