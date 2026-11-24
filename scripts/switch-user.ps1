
# ==========================================
# LAYER7 - WINDOWS USER SWITCH
# ==========================================

$ErrorActionPreference = "Stop"

$Username = "Layer7"
$TaskName = "Layer7_Switch_To_Login"

Write-Host "================================"
Write-Host "       LAYER7 USER SWITCH"
Write-Host "================================"

# 1. Check administrator privileges
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges required!"
    exit 1
}

# 2. Check Layer7 account
$User = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

if (-not $User) {
    Write-Error "User Layer7 does not exist!"
    exit 1
}

# 3. Enable Layer7
Enable-LocalUser -Name $Username

# 4. Set Layer7 as preferred login account
$LogonUI = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"

if (-not (Test-Path $LogonUI)) {
    New-Item -Path $LogonUI -Force | Out-Null
}

Set-ItemProperty -Path $LogonUI -Name "LastLoggedOnUser" -Value ".\Layer7"
Set-ItemProperty -Path $LogonUI -Name "LastLoggedOnSAMUser" -Value "$env:COMPUTERNAME\Layer7"

# 5. Get current session
$SessionID = (Get-Process -Id $PID).SessionId

Write-Host "Current Session: $SessionID"

# 6. Create delayed task to switch session to console
$Action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c tscon $SessionID /dest:console"

$Trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddSeconds(20)

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

# Remove old task
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register new task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force | Out-Null

Write-Host "Layer7 account enabled."
Write-Host "Preferred login: Layer7"
Write-Host "Session switch scheduled in 20 seconds."
Write-Host "================================"
