<#
.SYNOPSIS
  Stok yazılım çalışırken ADB üzerinden tüm bölümleri yedekler (kutuyu açmadan / EDL'siz).

.DESCRIPTION
  Ön koşul: stok yazılımda ADB açık olmalı. Bu dongle'larda genelde
  cihaz takılıyken tarayıcıdan şu adreslerden biri ADB'yi açar:
     http://192.168.100.1/usbdebug.html
     http://192.168.0.1/usbdebug.html
  Ardından "adb devices" cihazı göstermelidir.

  Her bölüm "adb exec-out dd" ile doğrudan PC'ye akıtılır (cihazda yer gerekmez),
  cihaz tarafında ve PC tarafında hash karşılaştırılır.

  NOT: EDL yedeği (backup-edl.ps1) her zaman daha güvenilirdir; bu script hızlı
  ilk yedek ve EDL'e geçmeden önceki güvenlik ağı içindir.
#>
param([string]$Serial = '')
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Adb  = Join-Path $Root 'tools\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { throw "adb bulunamadı. Önce scripts\windows\setup-tools.ps1 çalıştırın." }
$sArg = if ($Serial) { "-s $Serial" } else { '' }

function AdbSh([string]$cmd) { (& $Adb @($(if ($Serial) { '-s', $Serial })) shell $cmd) -join "`n" }

& $Adb devices
$state = (& $Adb @($(if ($Serial) { '-s', $Serial })) get-state 2>$null)
if ($state -ne 'device') { throw "ADB cihazı yok. usbdebug.html sayfasını açtınız mı? (docs/02-backup-restore.md)" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out   = Join-Path $Root "backups\adb-$stamp"
New-Item -ItemType Directory -Force "$Out\parts", "$Out\info" | Out-Null

# Cihaz bilgisi (sonradan donanım tespiti için çok değerli)
$info = [ordered]@{
    'getprop.txt'     = 'getprop'
    'uname.txt'       = 'uname -a'
    'cpuinfo.txt'     = 'cat /proc/cpuinfo'
    'meminfo.txt'     = 'cat /proc/meminfo'
    'partitions.txt'  = 'cat /proc/partitions'
    'by-name.txt'     = 'ls -l /dev/block/bootdevice/by-name/ 2>/dev/null || ls -l /dev/block/platform/*/by-name/'
    'mounts.txt'      = 'cat /proc/mounts'
    'cmdline.txt'     = 'cat /proc/cmdline'
    'dmesg.txt'       = 'dmesg'
    'whoami.txt'      = 'id'
    'ifconfig.txt'    = 'ip addr 2>/dev/null || ifconfig -a'
    'compatible.txt'  = 'cat /proc/device-tree/compatible 2>/dev/null; echo; cat /proc/device-tree/model 2>/dev/null'
}
foreach ($k in $info.Keys) { AdbSh $info[$k] | Set-Content -Encoding utf8 (Join-Path "$Out\info" $k) }
Write-Host "[+] Cihaz bilgisi: $Out\info" -ForegroundColor Green

# Root mu?
if ((AdbSh 'id') -notmatch 'uid=0') { Write-Warning 'ADB root değil; bölüm okumak başarısız olabilir.' }

# Bölüm listesini çıkar
$byName = AdbSh 'ls /dev/block/bootdevice/by-name/ 2>/dev/null || ls /dev/block/platform/*/by-name/'
$base   = AdbSh 'if [ -d /dev/block/bootdevice/by-name ]; then echo /dev/block/bootdevice/by-name; else ls -d /dev/block/platform/*/by-name | head -n1; fi'
$base   = $base.Trim()
$parts  = $byName -split '\s+' | Where-Object { $_ -and $_ -notmatch '^/' }
Write-Host "[*] $($parts.Count) bölüm bulundu ($base)" -ForegroundColor Cyan

# userdata/cache büyük ve önemsiz -> atlanabilir ama varsayılan olarak hepsini alıyoruz
$sums = @()
foreach ($p in $parts) {
    $dst = Join-Path "$Out\parts" "$p.bin"
    Write-Host "    -> $p" -NoNewline
    # Binary güvenli aktarım için cmd yönlendirmesi (PowerShell 5.1 boru hattı ikili veriyi bozar)
    cmd /c "`"$Adb`" $sArg exec-out dd if=$base/$p bs=4096 2>NUL > `"$dst`""
    $remote = (AdbSh "md5sum $base/$p 2>/dev/null || busybox md5sum $base/$p").Split(' ')[0].Trim()
    $local  = (Get-FileHash $dst -Algorithm MD5).Hash.ToLower()
    $ok     = $remote -eq $local
    Write-Host ("  {0:N0} bayt  {1}" -f (Get-Item $dst).Length, $(if ($ok) { 'OK' } else { "HASH UYUŞMAZ ($remote)" })) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
    $sums += "$local  parts/$p.bin  remote=$remote"
}
$sums | Set-Content -Encoding ascii (Join-Path $Out 'MD5SUMS.txt')

Write-Host ''
Write-Host "[+] ADB yedeği tamam: $Out" -ForegroundColor Green
Write-Host '    Uyuşmayan hash varsa o bölümü yeniden alın veya EDL yedeği kullanın.' -ForegroundColor Yellow
