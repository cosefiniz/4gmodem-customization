<#
.SYNOPSIS
  MSM8916 dongle'ın TAM yedeğini EDL (Qualcomm 9008 / firehose) üzerinden alır.

.DESCRIPTION
  Üç katmanlı yedek alır:
    1. gpt/   : bölüm tablosu (printgpt çıktısı + ham GPT)
    2. parts/ : her bölüm ayrı .bin + rawprogram0.xml (geri yükleme için)
    3. full/  : tüm eMMC'nin birebir imajı (son çare geri dönüş)
  Sonra her dosyanın SHA256 değerini SHA256SUMS.txt'ye yazar.

  Cihaz EDL modunda olmalı (Aygıt Yöneticisi'nde "QUSB__BULK" veya
  "Qualcomm HS-USB QDLoader 9008", VID_05C6&PID_9008). EDL'e girmek için:
    - Stok yazılımda adb açıksa:  tools\platform-tools\adb.exe reboot edl
    - Ya da cihaz fişten çekiliyken kart üzerindeki tuşa basılı tutup takın
      (bazı kartlarda tuş yerine iki test noktasını kısa devre etmek gerekir,
      docs/02-backup-restore.md'ye bakın).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\windows\backup-edl.ps1
  powershell -ExecutionPolicy Bypass -File scripts\windows\backup-edl.ps1 -SkipFull
#>
param(
    [switch]$SkipFull,            # tam eMMC imajını atla (yaklaşık 4 GB, uzun sürer)
    [string]$Loader = ''          # özel firehose loader yolu (boşsa edl otomatik seçer)
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Edl  = Join-Path $Root '.venv\Scripts\edl.exe'
if (-not (Test-Path $Edl)) { throw "edl bulunamadı. Önce scripts\windows\setup-tools.ps1 çalıştırın." }

# Cihaz EDL modunda mı?
$dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' }
if (-not $dev) {
    throw "EDL (05C6:9008) aygıtı bulunamadı. Cihazı EDL moduna alın ve Zadig ile WinUSB sürücüsünü kurun."
}
Write-Host "[+] EDL aygıtı: $($dev.FriendlyName) [$($dev.Status)]" -ForegroundColor Green

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out   = Join-Path $Root "backups\edl-$stamp"
New-Item -ItemType Directory -Force "$Out\gpt", "$Out\parts", "$Out\full" | Out-Null
$common = @('--memory=emmc')
if ($Loader) { $common += "--loader=$Loader" }

function Invoke-Edl([string[]]$EdlArgs, [string]$LogName) {
    Write-Host "[*] edl $($EdlArgs -join ' ')" -ForegroundColor Cyan
    & $Edl @EdlArgs @common 2>&1 | Tee-Object -FilePath (Join-Path $Out $LogName)
    if ($LASTEXITCODE -ne 0) { throw "edl hata kodu $LASTEXITCODE ($LogName)" }
}

Invoke-Edl @('printgpt')                          'printgpt.log'
Invoke-Edl @('getstorageinfo')                    'storageinfo.log'
Invoke-Edl @('gpt', "$Out\gpt", '--genxml')       'gpt.log'
Invoke-Edl @('rl',  "$Out\parts", '--genxml')     'parts.log'
if (-not $SkipFull) {
    Invoke-Edl @('rf', "$Out\full\emmc_full.bin") 'full.log'
}

Write-Host '[*] SHA256 hesaplanıyor...' -ForegroundColor Cyan
Get-ChildItem $Out -Recurse -File -Include *.bin, *.img, *.xml |
    Get-FileHash -Algorithm SHA256 |
    ForEach-Object { '{0}  {1}' -f $_.Hash.ToLower(), $_.Path.Substring($Out.Length + 1) } |
    Set-Content -Encoding ascii (Join-Path $Out 'SHA256SUMS.txt')

# Kritik bölümler gerçekten alındı mı?
$critical = 'modemst1','modemst2','fsg','fsc','persist','sbl1','aboot','rpm','tz','hyp','modem','boot'
$missing  = $critical | Where-Object { -not (Test-Path "$Out\parts\$_.bin") }
if ($missing) {
    Write-Warning "Şu bölümler bulunamadı (kartınızda adı farklı olabilir, printgpt.log'a bakın): $($missing -join ', ')"
}

Write-Host ''
Write-Host "[+] Yedek tamam: $Out" -ForegroundColor Green
Write-Host '    Bu klasörü EN AZ iki ayrı yere kopyalayın (harici disk + bulut/şifreli arşiv).' -ForegroundColor Yellow
Write-Host '    modemst1/modemst2/fsg/persist cihazınıza özeldir; başka cihazın yedeği yerine geçmez.' -ForegroundColor Yellow
Write-Host '    Cihazı yeniden başlatmak için: .venv\Scripts\edl.exe reset'
