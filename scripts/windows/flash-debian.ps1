<#
.SYNOPSIS
  HMUF02'ye Debian imajını yazar (OpenStick akışı). İki aşama:

  -Stage edl       Cihaz EDL'de (05C6:9008):
                     aboot <- lk1st (aboot.mbn), boot bölümü silinir, reset.
                     Cihaz lk1st ile açılır, boot boş olduğu için fastboot'ta kalır (18D1:D00D).
                     Bu aygıt için Zadig ile WinUSB kurulmalı.
  -Stage fastboot  Cihaz lk1st fastboot'ta:
                     yeni GPT, aboot/hyp/rpm/sbl1/tz, boot, rootfs, ardından cihaza özel
                     bölümler (fsc fsg modem modemst1 modemst2 persist sec) KENDİ yedeğinden.
                     Sonra reboot.

.PARAMETER Image   Artifact klasörü (aboot.mbn, gpt_both0.bin, boot.bin, rootfs.bin ...)
.PARAMETER Backup  EDL yedeği klasörü (parts\ içinde cihaza özel bölümler)
.PARAMETER Yes     Onay sorusunu atla (yalnızca kullanıcı sohbette açıkça onay verdiyse)

.NOTES
  Geri dönüş: cihazı tuşla EDL'e alın, restore-edl.ps1 -Mode full.
#>
param(
    [Parameter(Mandatory)] [ValidateSet('edl', 'fastboot')] [string]$Stage,
    [Parameter(Mandatory)] [string]$Image,
    [Parameter(Mandatory)] [string]$Backup,
    [switch]$Yes
)
$ErrorActionPreference = 'Stop'
$Root  = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Py    = Join-Path $Root '.venv\Scripts\python.exe'
$EdlPy = Join-Path $Root 'third_party\edl\edl.py'
$Fb    = Join-Path $Root 'tools\platform-tools\fastboot.exe'
$Image  = (Resolve-Path $Image).Path
$Backup = (Resolve-Path $Backup).Path
$Parts  = Join-Path $Backup 'parts'

# --- Ön kontroller -----------------------------------------------------------
Write-Host '[*] İmaj bütünlüğü (SHA256SUMS)...' -ForegroundColor Cyan
foreach ($line in Get-Content (Join-Path $Image 'SHA256SUMS')) {
    $hash, $rel = $line -split '\s+', 2
    $rel = $rel.TrimStart('*').Replace('./', '')
    if ((Get-FileHash (Join-Path $Image $rel) -Algorithm SHA256).Hash.ToLower() -ne $hash) { throw "İmaj bozuk: $rel" }
}
$need = 'fsc', 'fsg', 'modem', 'modemst1', 'modemst2', 'persist', 'sec'
foreach ($n in $need) { if (-not (Test-Path "$Parts\$n.bin")) { throw "Yedekte $n.bin yok: $Parts" } }
if (-not (Test-Path "$Backup\full")) { throw "Yedekte full\ imaj yok; geri dönüş için gerekli." }
Write-Host '[+] İmaj ve yedek tamam.' -ForegroundColor Green

function Confirm-Step([string]$What) {
    Write-Host "`n$What" -ForegroundColor Yellow
    if ($Yes) { Write-Host '(-Yes verildi)'; return }
    if ((Read-Host "Devam için 'EVET' yazın") -ne 'EVET') { Write-Host 'İptal.'; exit 1 }
}
function Run([string]$Exe, [string[]]$A) {
    Write-Host "[>] $(Split-Path $Exe -Leaf) $($A -join ' ')" -ForegroundColor Cyan
    $ErrorActionPreference = 'Continue'
    & $Exe @A 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'Progress:' }
    if ($LASTEXITCODE -ne 0) { throw "Komut başarısız (kod $LASTEXITCODE)" }
}

# --- Aşama 1: EDL -------------------------------------------------------------
if ($Stage -eq 'edl') {
    if (-not (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' })) {
        throw 'Cihaz EDL modunda değil (05C6:9008).'
    }
    Confirm-Step 'EDL: aboot <- lk1st yazılacak ve boot bölümü silinecek. Stok Android bundan sonra açılmaz (yedekten geri dönülebilir).'
    Run $Py @($EdlPy, 'w', 'aboot', "$Image\aboot.mbn", '--memory=emmc')
    Run $Py @($EdlPy, 'e', 'boot', '--memory=emmc')
    Run $Py @($EdlPy, 'reset', '--memory=emmc')
    Write-Host "`n[+] Aşama 1 tamam. Cihaz lk1st fastboot'ta açılmalı (18D1:D00D)." -ForegroundColor Green
    Write-Host '    Aygıt Yöneticisi''nde sürücüsüz görünürse Zadig ile WinUSB kurun, sonra -Stage fastboot.'
    exit 0
}

# --- Aşama 2: fastboot --------------------------------------------------------
$dev = (& $Fb devices) -join "`n"
if (-not $dev.Trim()) { throw 'fastboot cihaz görmüyor. Zadig ile 18D1:D00D için WinUSB kurdunuz mu?' }
Write-Host "fastboot: $dev"

Confirm-Step 'fastboot: bölüm tablosu değişecek, önyükleme zinciri + Debian yazılacak, cihaza özel bölümler yedekten geri yazılacak.'
Run $Fb @('flash', 'partition', "$Image\gpt_both0.bin")
foreach ($p in 'aboot', 'hyp', 'rpm', 'sbl1', 'tz') { Run $Fb @('flash', $p, "$Image\$p.mbn") }
Run $Fb @('flash', 'boot', "$Image\boot.bin")
Run $Fb @('flash', 'rootfs', "$Image\rootfs.bin")
foreach ($n in $need) { Run $Fb @('flash', $n, "$Parts\$n.bin") }
Run $Fb @('reboot')

Write-Host "`n[+] Flaşlama tamam. Yaklaşık 30-60 sn sonra USB ağ (192.168.5.1) gelmeli." -ForegroundColor Green
Write-Host '    ssh user@192.168.5.1  (parola: 1, hemen değiştirin)'
