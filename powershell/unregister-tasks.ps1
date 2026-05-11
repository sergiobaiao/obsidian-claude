# unregister-tasks.ps1
# Removes the three scheduled tasks without touching vault files.

foreach ($name in @("ClaudeVaultWatch","ObsidianTopicLinker","ClaudeVaultCoworkPeriodic")) {
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed: $name"
}
Write-Host "Done."
