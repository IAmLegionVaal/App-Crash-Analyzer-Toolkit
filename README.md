# App Crash Analyzer Toolkit

A PowerShell toolkit for L1/L2 application-crash diagnostics and selected guarded Windows repair actions.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\App_Crash_Analyzer_Toolkit.ps1 -Hours 72
```

## Repair script

Preview a package reset:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\App_Crash_Repair_Toolkit.ps1 -AppPackageName Microsoft.WindowsCalculator -ResetAppPackage -DryRun
```

Examples:

```powershell
.\App_Crash_Repair_Toolkit.ps1 -AppPackageName Microsoft.WindowsCalculator -ResetAppPackage
.\App_Crash_Repair_Toolkit.ps1 -RestartWindowsErrorReporting
.\App_Crash_Repair_Toolkit.ps1 -ArchiveAndClearWerQueue
.\App_Crash_Repair_Toolkit.ps1 -RepairSystemFiles
```

## Repair behavior

- Requires an elevated PowerShell session.
- Resets one exact AppX/MSIX package, using `Reset-AppxPackage` when available and manifest re-registration as a fallback.
- Saves package metadata before a package reset.
- Can restart the Windows Error Reporting service.
- Archives Windows Error Reporting queues to ZIP before clearing them.
- Can run DISM RestoreHealth followed by System File Checker.
- Supports `-DryRun`, confirmation or `-Yes`, timestamped logs, post-repair verification and clear exit codes.

Exit codes are `0` success, `2` invalid input, `3` missing privileges or prerequisites, `4` cancelled, `5` action failure and `6` verification failure.

## Safety

Package reset can remove application-specific local settings. WER cleanup is performed only after an archive is created. DISM and SFC can take a long time and should not be interrupted. The tool does not uninstall applications or delete arbitrary application data.

## Author

Dewald Pretorius — L2 IT Support Engineer
