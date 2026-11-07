<#
.SYNOPSIS
  Windows üzerinde gerekli araçları kurar: adb/fastboot (Google platform-tools),
  bkerler/edl (Qualcomm EDL/firehose aracı) ve bunun için Python sanal ortamı.

.NOTES
  Repo kökünden çalıştırın:
    powershell -ExecutionPolicy Bypass -File scripts\windows\setup-tools.ps1
  EDL (9008) modunda cihaz için WinUSB sürücüsü gerekir: Zadig ile
  "QUSB__BULK" / "Qualcomm HS-USB QDLoader 9008" (VID 05C6, PID 9008) aygıtına WinUSB kurun.
#>
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $Root

$Tools = Join-Path $Root 'tools'
$Third = Join-Path $Root 'third_party'
New-Item -ItemType Directory -Force $Tools, $Third | Out-Null

# 1) platform-tools (adb / fastboot)
if (-not (Test-Path "$Tools\platform-tools\adb.exe")) {
    Write-Host '[*] platform-tools indiriliyor...' -ForegroundColor Cyan
    $zip = Join-Path $Tools 'platform-tools.zip'
    Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive $zip -DestinationPath $Tools -Force
    Remove-Item $zip
}
& "$Tools\platform-tools\adb.exe" version

# 2) bkerler/edl
if (-not (Test-Path "$Third\edl\edl.py")) {
    Write-Host '[*] bkerler/edl klonlanıyor...' -ForegroundColor Cyan
    git clone --depth 1 https://github.com/bkerler/edl.git "$Third\edl"
    git -C "$Third\edl" submodule update --init --depth 1
}

# 3) Python venv + edl
if (-not (Test-Path "$Root\.venv\Scripts\python.exe")) {
    Write-Host '[*] Python sanal ortamı oluşturuluyor...' -ForegroundColor Cyan
    python -m venv "$Root\.venv"
}
& "$Root\.venv\Scripts\python.exe" -m pip install --upgrade pip
& "$Root\.venv\Scripts\python.exe" -m pip install -e "$Third\edl"

Write-Host ''
Write-Host '[+] Kurulum tamam.' -ForegroundColor Green
Write-Host '    adb      : tools\platform-tools\adb.exe'
Write-Host '    fastboot : tools\platform-tools\fastboot.exe'
Write-Host '    edl      : .venv\Scripts\edl.exe'
Write-Host ''
Write-Host 'EDL sürücüsü için Zadig: https://zadig.akeo.ie  (winget install akeo.ie.Zadig)' -ForegroundColor Yellow
