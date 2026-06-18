#requires -Version 5.1
<#
.SYNOPSIS
    App Crash Analyzer Toolkit.
.DESCRIPTION
    Diagnostic-only script for summarising recent Windows application crashes and hangs.
#>
[CmdletBinding()]
param([int]$Hours = 48,[string]$OutputPath,[string]$ProcessName)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'App_Crash_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
$Start = (Get-Date).AddHours(-1 * $Hours)

function Export-Data { param($Name,$Data) $Data | Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8; $Data | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8 }

$events = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$Start} -ErrorAction SilentlyContinue | Where-Object {
    $_.ProviderName -in @('Application Error','Windows Error Reporting','Application Hang') -or $_.Id -in @(1000,1001,1002)
}

if ($ProcessName) { $events = $events | Where-Object { $_.Message -match [regex]::Escape($ProcessName) } }

$eventRows = $events | Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message
Export-Data -Name "app_crash_events_$RunStamp" -Data $eventRows

$summary = $events | ForEach-Object {
    $msg = $_.Message
    $app = if ($msg -match 'Faulting application name:\s*([^,]+)') { $matches[1] } elseif ($msg -match 'Faulting application path:\s*(.+)') { Split-Path $matches[1] -Leaf } else { 'Unknown' }
    $module = if ($msg -match 'Faulting module name:\s*([^,]+)') { $matches[1] } else { 'Unknown' }
    [PSCustomObject]@{TimeCreated=$_.TimeCreated;EventId=$_.Id;Provider=$_.ProviderName;Application=$app;FaultingModule=$module}
}
Export-Data -Name "app_crash_summary_$RunStamp" -Data $summary

$topApps = $summary | Group-Object Application | Sort-Object Count -Descending | Select-Object Count,Name
$topModules = $summary | Group-Object FaultingModule | Sort-Object Count -Descending | Select-Object Count,Name
Export-Data -Name "top_crashing_apps_$RunStamp" -Data $topApps
Export-Data -Name "top_faulting_modules_$RunStamp" -Data $topModules

$report = @"
<h1>App Crash Analyzer - $env:COMPUTERNAME</h1>
<p>Generated: $(Get-Date)<br>Time window: Last $Hours hours</p>
<h2>Top Applications</h2>
$($topApps | ConvertTo-Html -Fragment)
<h2>Top Faulting Modules</h2>
$($topModules | ConvertTo-Html -Fragment)
<h2>Recent Events</h2>
$($summary | Select-Object -First 100 | ConvertTo-Html -Fragment)
"@
$report | ConvertTo-Html -Title 'App Crash Analyzer' | Set-Content (Join-Path $OutputPath "app_crash_report_$RunStamp.html") -Encoding UTF8

$topApps | Format-Table -AutoSize
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
