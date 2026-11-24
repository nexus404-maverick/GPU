
$ErrorActionPreference = "Stop"

$Username = "Layer7"

if ([string]::IsNullOrWhiteSpace($env:LAYER7_PASSWORD)) {
    throw "LAYER7_PASSWORD is missing."
}

$Password = ConvertTo-SecureString $env:LAYER7_PASSWORD -AsPlainText -Force

if (!(Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $Username `
        -Password $Password `
        -FullName "Layer7" `
        -PasswordNeverExpires
}

Enable-LocalUser -Name $Username

Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction SilentlyContinue

Write-Host "Layer7 account ready."
