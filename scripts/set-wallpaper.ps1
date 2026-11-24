
# ==========================================
# LAYER7 - WINDOWS WALLPAPER INSTALLER
# Windows Server 2025
# ==========================================

$ErrorActionPreference = "Stop"

$Username = "Layer7"
$WallpaperFolder = "$env:GITHUB_WORKSPACE\Wallpaper"
$DestinationFolder = "C:\ProgramData\Layer7\Wallpaper"

Write-Host "===================================="
Write-Host "       LAYER7 WALLPAPER SETUP"
Write-Host "===================================="

# 1. Find wallpaper
$Wallpaper = @(
    "$WallpaperFolder\wallpaper.jpg",
    "$WallpaperFolder\wallpaper.png"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (!$Wallpaper) {
    throw "Wallpaper.jpg or wallpaper.png not found!"
}

# 2. Create destination folder
New-Item -ItemType Directory `
    -Path $DestinationFolder `
    -Force | Out-Null

# 3. Copy wallpaper
$Extension = [IO.Path]::GetExtension($Wallpaper)
$Destination = Join-Path $DestinationFolder "wallpaper$Extension"

Copy-Item -Path $Wallpaper -Destination $Destination -Force

Write-Host "Wallpaper copied: $Destination"

# 4. Find Layer7 profile
$Profile = Get-CimInstance Win32_UserProfile |
    Where-Object {
        $_.LocalPath -eq "C:\Users\$Username"
    }

if (!$Profile) {
    Write-Host "Layer7 profile not created yet."
    Write-Host "Wallpaper will be configured after profile creation."
    exit 0
}

# 5. Configure Layer7 registry
$HiveName = "Layer7Wallpaper"

try {
    if (!$Profile.Loaded) {
        $HiveFile = "$($Profile.LocalPath)\NTUSER.DAT"

        if (Test-Path $HiveFile) {
            reg.exe load "HKU\$HiveName" "$HiveFile"

            if ($LASTEXITCODE -ne 0) {
                throw "Cannot load Layer7 registry hive."
            }

            $RegistryPath = "Registry::HKEY_USERS\$HiveName\Control Panel\Desktop"

            Set-ItemProperty -Path $RegistryPath `
                -Name Wallpaper `
                -Value $Destination

            Set-ItemProperty -Path $RegistryPath `
                -Name WallpaperStyle `
                -Value "10"

            Set-ItemProperty -Path $RegistryPath `
                -Name TileWallpaper `
                -Value "0"
        }
    }
    else {
        $RegistryPath = "Registry::HKEY_USERS\$($Profile.SID)\Control Panel\Desktop"

        Set-ItemProperty -Path $RegistryPath `
            -Name Wallpaper `
            -Value $Destination

        Set-ItemProperty -Path $RegistryPath `
            -Name WallpaperStyle `
            -Value "10"

        Set-ItemProperty -Path $RegistryPath `
            -Name TileWallpaper `
            -Value "0"
    }

    Write-Host "Layer7 wallpaper configured."
}
finally {
    if (!$Profile.Loaded) {
        reg.exe unload "HKU\$HiveName" 2>$null
    }
}

Write-Host "===================================="
Write-Host "       WALLPAPER SETUP DONE"
Write-Host "===================================="
