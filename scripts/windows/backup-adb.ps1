<#
.SYNOPSIS
  Stok yazılım çalışırken ADB üzerinden tüm bölümleri ve tüm eMMC'yi yedekler (EDL'siz).

.DESCRIPTION
  HMUF02 stok yazılımında (Android 4.4 userdebug, USB 05C6:9024) ADB varsayılan açık.
  "adb root" parola ister; bunun yerine şu kalıcı olmayan yöntem kullanılır:
      setprop service.adb.root 1; busybox killall adbd
  (Cihaz yeniden başlayınca ADB normal kullanıcıya döner.)

  Android 4.4 adbd "exec-out" desteklemez; aktarım "adb pull <blok aygıtı>" ile yapılır.
  Her bölümün MD5'i cihazda (busybox md5sum) ve PC'de hesaplanıp karşılaştırılır.

  Çıktı: backups\adb-<tarih>\
     info\        cihaz bilgisi (getprop, bölüm listesi, cpuinfo...)
     parts\       her bölüm ayrı .bin
     full\        mmcblk0.bin: tüm eMMC (GPT dahil), -SkipFull ile atlanır
     MD5SUMS.txt  PC ve cihaz hash'leri, SHA256SUMS.txt

  Not: Sistem çalışırken alındığı için yazılabilir bağlı bölümler (userdata, cache)
  okuma sırasında değişebilir; bunlar için hash uyuşmazlığı normaldir.
  Kritik bölümler (modemst*, fsg, fsc, persist, modem, sec, sbl1, aboot, tz, rpm, hyp) mutlaka OK olmalı.

  Diğer programların eski ADB sunucuları (ör. SuperDisplay) cihazı sahiplenebilir;
  önce onları kapatın.
#>
param(
    [switch]$SkipFull,
    [switch]$SkipUserdata
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Adb  = Join-Path $Root 'tools\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { throw "adb bulunamadı. Önce scripts\windows\setup-tools.ps1 çalıştırın." }

function AdbSh([string]$cmd) { ((& $Adb shell $cmd) -join "`n").Replace("`r", '') }

if ((& $Adb get-state 2>$null) -ne 'device') { throw 'ADB cihazı yok. detect-device.ps1 ile kontrol edin.' }
# PowerShell 5.1, adb'nin stderr çıktısını hata sayar; bundan sonra hatalar açıkça kontrol ediliyor.
$ErrorActionPreference = 'Continue'

# Root
if ((AdbSh 'id') -notmatch 'uid=0') {
    Write-Host '[*] ADB root olarak yeniden başlatılıyor (geçici)...' -ForegroundColor Cyan
    AdbSh 'setprop service.adb.root 1' | Out-Null
    & $Adb shell 'busybox killall adbd' 2>$null | Out-Null
    Start-Sleep -Seconds 4
    & $Adb wait-for-device
    if ((AdbSh 'id') -notmatch 'uid=0') { throw 'Root alınamadı.' }
}
Write-Host '[+] ADB root' -ForegroundColor Green

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out   = Join-Path $Root "backups\adb-$stamp"
New-Item -ItemType Directory -Force "$Out\parts", "$Out\info", "$Out\full" | Out-Null

$info = [ordered]@{
    'getprop.txt'    = 'getprop'
    'cpuinfo.txt'    = 'cat /proc/cpuinfo'
    'meminfo.txt'    = 'cat /proc/meminfo'
    'version.txt'    = 'cat /proc/version'
    'cmdline.txt'    = 'cat /proc/cmdline'
    'partitions.txt' = 'cat /proc/partitions'
    'by-name.txt'    = 'ls -l /dev/block/bootdevice/by-name/'
    'mounts.txt'     = 'cat /proc/mounts'
    'dmesg.txt'      = 'dmesg'
    'netcfg.txt'     = 'netcfg; busybox ifconfig -a'
    'emmc-cid.txt'   = 'cat /sys/block/mmcblk0/device/cid /sys/block/mmcblk0/device/name /sys/block/mmcblk0/device/manfid 2>/dev/null'
    'dt-model.txt'   = 'cat /proc/device-tree/model 2>/dev/null; echo; cat /proc/device-tree/compatible 2>/dev/null'
    'lsmod.txt'      = 'lsmod'
    'services.txt'   = 'getprop | busybox grep init.svc'
}
foreach ($k in $info.Keys) { AdbSh $info[$k] | Set-Content -Encoding utf8 (Join-Path "$Out\info" $k) }
# Stok çekirdeğin çalışan device tree'si (ham .dtb). dtc -I dtb -O dts ile okunabilir.
& $Adb pull /sys/firmware/fdt "$Out\info\stock-running.dtb" 2>&1 | Out-Null
Write-Host "[+] Cihaz bilgisi: $Out\info" -ForegroundColor Green

$base  = '/dev/block/bootdevice/by-name'
$parts = (AdbSh "ls $base") -split '\s+' | Where-Object { $_ } | Sort-Object
if ($SkipUserdata) { $parts = $parts | Where-Object { $_ -ne 'userdata' } }
$volatile = 'userdata', 'cache'

$targets = @($parts | ForEach-Object { [pscustomobject]@{ Name = $_; Remote = "$base/$_"; Local = "$Out\parts\$_.bin"; Rel = "parts/$_.bin" } })
if (-not $SkipFull) { $targets += [pscustomobject]@{ Name = 'mmcblk0 (tam eMMC)'; Remote = '/dev/block/mmcblk0'; Local = "$Out\full\mmcblk0.bin"; Rel = 'full/mmcblk0.bin' } }

Write-Host "[*] $($targets.Count) hedef okunacak" -ForegroundColor Cyan
$md5 = @(); $bad = @()
foreach ($t in $targets) {
    Write-Host ("    -> {0,-22}" -f $t.Name) -NoNewline
    & $Adb pull $t.Remote $t.Local 2>&1 | Out-Null
    if (-not (Test-Path $t.Local)) { Write-Host ' OKUNAMADI' -ForegroundColor Red; $bad += $t.Name; continue }
    $remote = ((AdbSh "busybox md5sum $($t.Remote)") -split '\s+')[0]
    $local  = (Get-FileHash $t.Local -Algorithm MD5).Hash.ToLower()
    $ok = $remote -eq $local
    $color = if ($ok) { 'Green' } elseif ($volatile -contains $t.Name -or $t.Name -like 'mmcblk0*') { 'Yellow' } else { 'Red' }
    Write-Host ("{0,15:N0} bayt  {1}" -f (Get-Item $t.Local).Length, $(if ($ok) { 'OK' } else { 'HASH FARKLI' })) -ForegroundColor $color
    if (-not $ok -and $color -eq 'Red') { $bad += $t.Name }
    $md5 += "$local  $($t.Rel)  device=$remote  $(if ($ok) {'OK'} else {'MISMATCH'})"
}
$md5 | Set-Content -Encoding ascii (Join-Path $Out 'MD5SUMS.txt')

Write-Host '[*] SHA256 hesaplanıyor...' -ForegroundColor Cyan
Get-ChildItem $Out -Recurse -File -Include *.bin |
    Get-FileHash -Algorithm SHA256 |
    ForEach-Object { '{0}  {1}' -f $_.Hash.ToLower(), $_.Path.Substring($Out.Length + 1).Replace('\', '/') } |
    Set-Content -Encoding ascii (Join-Path $Out 'SHA256SUMS.txt')

Write-Host ''
if ($bad) {
    Write-Warning "Sorunlu kritik bölümler: $($bad -join ', '). Scripti tekrar çalıştırın."
} else {
    Write-Host "[+] Yedek tamam, tüm kritik bölümler doğrulandı: $Out" -ForegroundColor Green
}
Write-Host '    Klasörü EN AZ iki ayrı yere kopyalayın. IMEI/MAC içerir; paylaşmayın.' -ForegroundColor Yellow
