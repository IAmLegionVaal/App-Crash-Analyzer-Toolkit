# App Crash Analyzer Toolkit

A read-only PowerShell toolkit for L1/L2 application crash troubleshooting.

## Features

- Recent Application Error events
- Windows Error Reporting events
- Top crashing applications
- Faulting module summary
- Recent app hang events
- Optional process search
- CSV, JSON, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\App_Crash_Analyzer_Toolkit.ps1
```

Check the last 72 hours:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\App_Crash_Analyzer_Toolkit.ps1 -Hours 72
```

## Safety

Diagnostic-only. It reads event logs and exports summaries.

## Suggested topics

```text
powershell
windows
eventlog
application-crash
helpdesk
it-support
troubleshooting
```
