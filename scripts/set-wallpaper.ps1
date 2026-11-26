
$ErrorActionPreference = 'Stop'

$TargetUser = 'Layer7'
$SourceWallpaper = Join-Path $env:GITHUB_WORKSPACE 'Wallpaper\wallpaper.jpg'
$WallpaperDirectory = 'C:\ProgramData\Layer7\Wallpaper'
$WallpaperPath = Join-Path $WallpaperDirectory 'wallpaper.jpg'

Write-Host '========================================'
Write-Host '       LAYER7 WALLPAPER SETUP'
Write-Host '========================================'

# 1. Kiểm tra quyền Administrator
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Script cần chạy bằng quyền Administrator.'
}

# 2. Kiểm tra ảnh nguồn
if (-not (Test-Path -LiteralPath $SourceWallpaper -PathType Leaf)) {
    throw "Không tìm thấy ảnh: $SourceWallpaper"
}

# 3. Lấy SID tài khoản Layer7
try {
    $account = New-Object System.Security.Principal.NTAccount(
        "$env:COMPUTERNAME\$TargetUser"
    )

    $sid = $account.Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}
catch {
    throw "Không tìm thấy tài khoản Windows $TargetUser."
}

Write-Host "User: $TargetUser"
Write-Host "SID: $sid"

# 4. Xác định thư mục hồ sơ thực tế
$profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"

if (-not (Test-Path $profileKey)) {
    throw "Chưa có hồ sơ Windows cho $TargetUser. Hãy chạy setup-user.ps1 trước."
}

$profilePath = (Get-ItemProperty -Path $profileKey).ProfileImagePath
$profilePath = [Environment]::ExpandEnvironmentVariables($profilePath)

$ntUserDat = Join-Path $profilePath 'NTUSER.DAT'

if (-not (Test-Path -LiteralPath $ntUserDat)) {
    throw "Không tìm thấy NTUSER.DAT: $ntUserDat"
}

Write-Host "Profile: $profilePath"

# 5. Sao chép ảnh vào thư mục dùng chung
New-Item -ItemType Directory -Path $WallpaperDirectory -Force | Out-Null

Copy-Item -LiteralPath $SourceWallpaper -Destination $WallpaperPath -Force

if (-not (Test-Path -LiteralPath $WallpaperPath)) {
    throw 'Sao chép hình nền thất bại.'
}

# 6. Cấp quyền đọc ảnh cho người dùng
& icacls.exe $WallpaperDirectory /grant '*S-1-5-32-545:(OI)(CI)RX' /T /C /Q

if ($LASTEXITCODE -ne 0) {
    throw 'Không thể cấp quyền đọc thư mục hình nền.'
}

Write-Host 'Wallpaper copied successfully.'

# 7. Mở registry của Layer7
$loadedHive = "Registry::HKEY_USERS\$sid"
$hiveName = "Layer7Wallpaper_$PID"
$mountedByScript = $false

try {
    if (Test-Path $loadedHive) {
        $registryPath = $loadedHive
        Write-Host 'Đang sử dụng registry profile đã được nạp.'
    }
    else {
        Write-Host 'Đang nạp NTUSER.DAT của Layer7...'

        & reg.exe load "HKU\$hiveName" $ntUserDat

        if ($LASTEXITCODE -ne 0) {
            throw 'Không thể nạp registry profile của Layer7.'
        }

        $mountedByScript = $true
        $registryPath = "Registry::HKEY_USERS\$hiveName"
    }

    # 8. Thiết lập hình nền
    $desktopKey = Join-Path $registryPath 'Control Panel\Desktop'

    New-Item -Path $desktopKey -Force | Out-Null

    Set-ItemProperty -Path $desktopKey -Name 'Wallpaper' -Value $WallpaperPath
    Set-ItemProperty -Path $desktopKey -Name 'WallpaperStyle' -Value '10'
    Set-ItemProperty -Path $desktopKey -Name 'TileWallpaper' -Value '0'

    # Tắt slideshow để giữ hình nền tĩnh
    $personalizeKey = Join-Path $registryPath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'

    New-Item -Path $personalizeKey -Force | Out-Null
    Set-ItemProperty -Path $personalizeKey -Name 'BackgroundType' -Value 0 -Type DWord

    Write-Host 'Đã cấu hình registry cho Layer7.'
}
finally {
    # Chỉ tháo registry nếu script tự nạp
    if ($mountedByScript) {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()

        & reg.exe unload "HKU\$hiveName"

        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'Không thể tháo registry hive. Cần kiểm tra lại.'
        }
    }
}

# 9. Nếu script đang chạy trực tiếp bằng Layer7,
# áp dụng hình nền ngay trong phiên tương tác hiện tại.
if ($currentIdentity.Name -match '\\Layer7$') {
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class Layer7WallpaperAPI
{
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(
        int action,
        int param,
        string path,
        int flags
    );
}
'@

        $result = [Layer7WallpaperAPI]::SystemParametersInfo(
            20,
            0,
            $WallpaperPath,
            3
        )

        if (-not $result) {
            Write-Warning 'Không thể làm mới hình nền phiên hiện tại.'
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

Write-Host '========================================'
Write-Host 'LAYER7 WALLPAPER CONFIGURATION COMPLETE'
Write-Host "Image: $WallpaperPath"
Write-Host "User: $TargetUser"
Write-Host '========================================'
