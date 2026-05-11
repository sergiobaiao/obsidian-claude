# register-tasks.ps1
# Registers the three Claude/Obsidian scheduled tasks on Windows.
# Run from an elevated or standard PowerShell prompt.
# Usage: .\register-tasks.ps1 -VaultPath "C:\Users\yourname\Nextcloud\Obsidian"

param(
    [string]$VaultPath = "$env:USERPROFILE\Nextcloud\Obsidian",
    [string]$ClaudeVaultHome = "$env:USERPROFILE\claude-vault"
)

$shimDir = $ClaudeVaultHome

function Register-ShimTask {
    param([string]$TaskName, [string]$ShimPath, [string]$Schedule, [int]$IntervalMinutes = 0)

    # Run via powershell -WindowStyle Hidden so no console window flashes on screen
    $psArgs = '-WindowStyle Hidden -NonInteractive -Command "& cmd.exe /c \"{0}\""' -f $ShimPath
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    if ($Schedule -eq "ONLOGON") {
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    } else {
        $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -Once -At (Get-Date)
    }

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Limited -Force | Out-Null
    Write-Host "  Registered: $TaskName" -ForegroundColor Green
}

Write-Host "`nRegistering scheduled tasks..." -ForegroundColor Cyan

# 1. Vault watcher — fires at logon
Register-ShimTask `
    -TaskName "ClaudeVaultWatch" `
    -ShimPath "$shimDir\run-claudevault-watch.cmd" `
    -Schedule "ONLOGON"

# 2. Topic linker — every 10 minutes
Register-ShimTask `
    -TaskName "ObsidianTopicLinker" `
    -ShimPath "$shimDir\run-topic-linker.cmd" `
    -Schedule "INTERVAL" `
    -IntervalMinutes 10

# 3. Cowork periodic sync — every 5 minutes
Register-ShimTask `
    -TaskName "ClaudeVaultCoworkPeriodic" `
    -ShimPath "$shimDir\run-cowork-periodic-sync.cmd" `
    -Schedule "INTERVAL" `
    -IntervalMinutes 5

# Start them all immediately
Write-Host "`nStarting tasks..." -ForegroundColor Cyan
foreach ($name in @("ClaudeVaultWatch","ObsidianTopicLinker","ClaudeVaultCoworkPeriodic")) {
    schtasks /Run /TN $name 2>$null
    Start-Sleep -Seconds 1
    $status = (schtasks /Query /TN $name /FO LIST /V 2>$null | Select-String "Status").ToString()
    Write-Host "  $name : $status"
}

Write-Host "`nDone. Verify in Task Scheduler or run: schtasks /Query /FO TABLE | findstr Claude" -ForegroundColor Cyan
