[CmdletBinding()]
param(
    [string]$AppPackageName,
    [switch]$ResetAppPackage,
    [switch]$RestartWindowsErrorReporting,
    [switch]$ArchiveAndClearWerQueue,
    [switch]$RepairSystemFiles,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$LogDirectory="$env:ProgramData\IAmLegionVaal\AppCrashRepair"
)

$ErrorActionPreference='Stop'
$ExitInvalidInput=2; $ExitPrerequisite=3; $ExitCancelled=4; $ExitActionFailure=5; $ExitVerificationFailure=6
function Test-Admin {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Write-Log([string]$Message){$line="{0:u} {1}" -f (Get-Date),$Message;Write-Host $line;Add-Content -LiteralPath $script:LogPath -Value $line}
function Invoke-Step([string]$Description,[scriptblock]$Action){if($DryRun){Write-Log "[DRY-RUN] $Description"}else{Write-Log "[ACTION] $Description";& $Action}}

if(-not($ResetAppPackage -or $RestartWindowsErrorReporting -or $ArchiveAndClearWerQueue -or $RepairSystemFiles)){Write-Error 'Select at least one repair action.';exit $ExitInvalidInput}
if($ResetAppPackage -and [string]::IsNullOrWhiteSpace($AppPackageName)){Write-Error '-AppPackageName is required with -ResetAppPackage.';exit $ExitInvalidInput}
if(-not(Test-Admin)){Write-Error 'Run from an elevated PowerShell session.';exit $ExitPrerequisite}

New-Item -ItemType Directory -Path $LogDirectory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$script:LogPath=Join-Path $LogDirectory "AppCrashRepair_$stamp.log";$backupDirectory=Join-Path $LogDirectory "Backup_$stamp";New-Item -ItemType Directory -Path $backupDirectory -Force|Out-Null
$werQueue=Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'
$werArchive=Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'
$package=$null
if($ResetAppPackage){
    try{$matches=@(Get-AppxPackage -Name $AppPackageName -ErrorAction Stop);if($matches.Count -ne 1){throw "Expected one installed package but found $($matches.Count). Use the exact package name."};$package=$matches[0];$package|Select-Object Name,PackageFullName,PackageFamilyName,InstallLocation,Version,Publisher|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $backupDirectory 'AppPackage.json') -Encoding UTF8;Write-Log "Saved package metadata for $($package.Name)."}
    catch{Write-Error "Unable to resolve app package: $($_.Exception.Message)";exit $ExitInvalidInput}
}
$werItems=@()
if($ArchiveAndClearWerQueue){
    foreach($path in @($werQueue,$werArchive)){if(Test-Path -LiteralPath $path){$werItems+=@(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)}}
    Write-Log "Found $($werItems.Count) WER report item(s) for archival."
}

$actions=@();if($ResetAppPackage){$actions+="reset app package $($package.Name)"};if($RestartWindowsErrorReporting){$actions+='restart Windows Error Reporting service'};if($ArchiveAndClearWerQueue){$actions+='archive and clear WER queue'};if($RepairSystemFiles){$actions+='run DISM RestoreHealth and SFC'}
if(-not $DryRun -and -not $Yes){$answer=Read-Host ("Proceed with: {0}? [y/N]" -f ($actions -join '; '));if($answer -notmatch '^(?i)y(es)?$'){Write-Log '[CANCELLED] No changes were made.';exit $ExitCancelled}}

try{
    if($ArchiveAndClearWerQueue){
        Invoke-Step 'Archive Windows Error Reporting queues before clearing them' {
            if($werItems.Count -gt 0){$zip=Join-Path $backupDirectory 'WER_Reports.zip';Compress-Archive -LiteralPath $werItems.FullName -DestinationPath $zip -Force -ErrorAction Stop;Write-Log "Created $zip";$werItems|Remove-Item -Recurse -Force -ErrorAction Stop}else{Write-Log '[INFO] No WER queue items required archival or removal.'}
        }
    }
    if($RestartWindowsErrorReporting){Invoke-Step 'Restart Windows Error Reporting service' {Set-Service -Name WerSvc -StartupType Manual;$service=Get-Service WerSvc;if($service.Status -eq 'Running'){Restart-Service -Name WerSvc -Force}else{Start-Service -Name WerSvc}}}
    if($ResetAppPackage){Invoke-Step "Reset app package '$($package.Name)'" {
        $reset=Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue
        if($reset){$package|Reset-AppxPackage -ErrorAction Stop}
        else{$manifest=Join-Path $package.InstallLocation 'AppXManifest.xml';if(-not(Test-Path -LiteralPath $manifest)){throw 'AppXManifest.xml was not found.'};Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop}
    }}
    if($RepairSystemFiles){Invoke-Step 'Run DISM RestoreHealth' {& dism.exe /Online /Cleanup-Image /RestoreHealth|ForEach-Object{Write-Log "[DISM] $_"};if($LASTEXITCODE -ne 0){throw "DISM exited with code $LASTEXITCODE"}};Invoke-Step 'Run System File Checker' {& sfc.exe /scannow|ForEach-Object{Write-Log "[SFC] $_"};if($LASTEXITCODE -notin 0,1){throw "SFC exited with code $LASTEXITCODE"}}}
}catch{Write-Log "[FAILED] $($_.Exception.Message)";exit $ExitActionFailure}
if($DryRun){Write-Log '[COMPLETE] Dry-run completed.';exit 0}

$verifyFailed=$false
try{
    if($ResetAppPackage){$after=Get-AppxPackage -Name $package.Name;Write-Log "[VERIFY] Package installed: $([bool]$after)";if(-not $after){$verifyFailed=$true}}
    if($RestartWindowsErrorReporting){$service=Get-Service WerSvc;Write-Log "[VERIFY] WerSvc status=$($service.Status); start type=$($service.StartType)";if($service.StartType -eq 'Disabled'){$verifyFailed=$true}}
    if($ArchiveAndClearWerQueue){$remaining=0;foreach($path in @($werQueue,$werArchive)){if(Test-Path -LiteralPath $path){$remaining+=@(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue).Count}};Write-Log "[VERIFY] Remaining WER report items: $remaining";if($remaining -gt 0){$verifyFailed=$true}}
}catch{Write-Log "[VERIFY-FAILED] $($_.Exception.Message)";$verifyFailed=$true}
if($verifyFailed){exit $ExitVerificationFailure}
Write-Log '[COMPLETE] Application repair and verification completed.'
exit 0
