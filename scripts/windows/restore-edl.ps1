<#
.SYNOPSIS
  backup-edl.ps1 ile alınmış yedeği EDL üzerinden geri yükler (cihazı stok haline döndürür).

.DESCRIPTION
  İki mod:
    -Mode parts : parts\ klasöründeki her bölümü yazar (önerilen, hızlı).
    -Mode full  : full\emmc_full.bin imajını tüm eMMC'ye yazar (son çare).
  Her iki modda da önce yedeğin SHA256 kontrolü yapılır.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\windows\restore-edl.ps1 -Backup backups\edl-20261107-150000 -Mode parts
#>
param(
    [Parameter(Mandatory)] [string]$Backup,
    [ValidateSet('parts', 'full')] [string]$Mode = 'parts',
    [string]$Loader = ''
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Edl  = Join-Path $Root '.venv\Scripts\edl.exe'
$Backup = Resolve-Path $Backup
$common = @('--memory=emmc'); if ($Loader) { $common += "--loader=$Loader" }

# 1) Yedek bütünlüğü
Write-Host '[*] SHA256 doğrulanıyor...' -ForegroundColor Cyan
$bad = 0
foreach ($line in Get-Content (Join-Path $Backup 'SHA256SUMS.txt')) {
    $hash, $rel = $line -split '\s\s', 2
    if ($Mode -eq 'parts' -and $rel -like 'full*') { continue }
    if ($Mode -eq 'full'  -and $rel -notlike 'full*') { continue }
    $f = Join-Path $Backup $rel
    if ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -ne $hash) { Write-Warning "BOZUK: $rel"; $bad++ }
}
if ($bad) { throw "$bad dosya bozuk, geri yükleme iptal." }

$dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' }
if (-not $dev) { throw 'EDL (05C6:9008) aygıtı yok.' }

Write-Host "Bu işlem cihazın eMMC'sinin üzerine yazacak ($Mode). Devam için 'EVET' yazın:" -ForegroundColor Yellow
if ((Read-Host) -ne 'EVET') { Write-Host 'İptal.'; exit 1 }

if ($Mode -eq 'parts') {
    & $Edl wl (Join-Path $Backup 'parts') @common
} else {
    & $Edl wf (Join-Path $Backup 'full\emmc_full.bin') @common
}
if ($LASTEXITCODE -ne 0) { throw "edl hata kodu $LASTEXITCODE" }
& $Edl reset @common
Write-Host '[+] Geri yükleme tamam, cihaz yeniden başlatılıyor.' -ForegroundColor Green
