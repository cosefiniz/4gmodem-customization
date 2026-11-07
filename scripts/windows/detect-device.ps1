<#
.SYNOPSIS
  Dongle'ın şu an hangi modda olduğunu tespit eder (stok, ADB, fastboot, EDL, Debian gadget).
#>
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Adb  = Join-Path $Root 'tools\platform-tools\adb.exe'
$Fb   = Join-Path $Root 'tools\platform-tools\fastboot.exe'

$known = @{
    'VID_05C6&PID_9008' = 'EDL / Qualcomm 9008 (firehose) -> backup-edl.ps1 kullanılabilir'
    'VID_18D1&PID_D00D' = 'Fastboot (stok aboot veya lk2nd)'
    'VID_05C6&PID_9024' = 'Stok yazılım (HMUF02): RNDIS + ADB -> backup-adb.ps1 kullanılabilir'
    'VID_05C6&PID_F00E' = 'Stok yazılım: RNDIS (+ADB olabilir)'
    'VID_05C6&PID_90B6' = 'Stok yazılım: diag/modem kompozit'
    'VID_05C6&PID_9091' = 'Stok yazılım: diag/modem/rmnet kompozit'
    'VID_1D6B&PID_0104' = 'Linux USB gadget (Debian/OpenStick: RNDIS/ECM + seri)'
}

$all = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_*' }
$hits = foreach ($d in $all) {
    foreach ($k in $known.Keys) { if ($d.InstanceId -match [regex]::Escape($k)) { [pscustomobject]@{ Mode = $known[$k]; Name = $d.FriendlyName; Status = $d.Status; Id = $d.InstanceId } } }
}
# Bilinmeyen Qualcomm / Android aygıtlarını da göster
$other = $all | Where-Object { $_.InstanceId -match 'VID_(05C6|18D1|1D6B|2C7C|19D2|12D1)' -and -not ($hits.Id -contains $_.InstanceId) }

if ($hits)  { $hits  | Format-Table -AutoSize | Out-String -Width 250 | Write-Host }
if ($other) { Write-Host 'Diğer Qualcomm/Android aygıtları:'; $other | Select-Object Status, FriendlyName, InstanceId | Format-Table -AutoSize | Out-String -Width 250 | Write-Host }
if (-not $hits -and -not $other) {
    Write-Warning 'Dongle USB üzerinde görünmüyor. Kontrol: USB portu/hub, LED yanıyor mu, kutusu açıkken USB fişi tam oturuyor mu?'
}

$net = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'RNDIS|NDIS|CDC|Ethernet Gadget|Remote' }
if ($net) { Write-Host 'USB ağ adaptörleri:'; $net | Select-Object Name, InterfaceDescription, Status | Format-Table -AutoSize | Out-String | Write-Host }

# Başka programların ADB sunucuları cihazı sahiplenir (ör. SuperDisplay, telefon yöneticileri)
$foreign = Get-CimInstance Win32_Process -Filter "Name='adb.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -ne (Resolve-Path $Adb -ErrorAction SilentlyContinue).Path }
if ($foreign) { Write-Warning "Başka bir adb.exe çalışıyor (PID $($foreign.ProcessId -join ', ')). Cihazı sahiplenebilir; sahibi programı (ör. SuperDisplay hizmeti) durdurun." }

if (Test-Path $Adb) { Write-Host '--- adb devices'; & $Adb devices }
if (Test-Path $Fb)  { Write-Host '--- fastboot devices'; & $Fb devices }
