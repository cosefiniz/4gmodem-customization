---
name: msm8916-dongle
description: Bu repodaki HMUF02-V05 MSM8916 4G USB dongle'ı ile çalışırken kullan. Yedek alma (adb/EDL), geri yükleme, lk2nd/fastboot flaşlama, device tree (dts/) düzenleme ve derleme, OpenStick-Builder Debian imajı, cihaz üzerinde Debian yapılandırması, LED/tuş/UART/Wi-Fi sorunları. Cihaza yazan her işlemden önce mutlaka yükle.
---

# MSM8916 dongle (HMUF02-V05) çalışma kuralları

## Cihaz gerçekleri
- SoC MSM8916, 512 MB RAM, 4 GB eMMC, WCN3620 Wi-Fi, kart HMUF02-V05 (UFI001 ailesi).
- Mainline taban: `msm8916-ufi.dtsi` + bizim `dts/msm8916-hmuf02.dts` (LED 71/72/73, tuş 37 aktif-yüksek).
- UART: kart ön yüzü `RX0/TX0/GND`, 3.3 V, 115200, `ttyMSM0`.
- USB kimlikleri: EDL `05C6:9008`, fastboot/lk2nd `18D1:D00D`, Linux gadget `1D6B:0104`.
- Araç yolları (repo kökünden): `tools\platform-tools\adb.exe`, `tools\platform-tools\fastboot.exe`, `.venv\Scripts\edl.exe`.

## Değişmez güvenlik kuralları
1. `backups\edl-*` altında doğrulanmış tam yedek (SHA256SUMS.txt + full\emmc_full.bin) yoksa cihaza **yazma** (edl w/wl/wf/e, fastboot flash/erase) komutu çalıştırma. Önce `scripts\windows\backup-edl.ps1`.
2. Cihaza yazan her komuttan önce kullanıcıya ne yazılacağını söyle ve onay al. Onay her seferinde ayrı alınır.
3. `modemst1`, `modemst2`, `fsg`, `fsc`, `persist`, `modem`, `sec` her zaman **kullanıcının kendi** yedeğinden gelir. İnternetten indirilen dökümleri asla yazma.
4. tz ve hyp birlikte değişir (DB410c tz + qhypstub). Asla karıştırma.
5. `backups\` içeriğini (IMEI/MAC) hiçbir yere yükleme, commit'leme veya sohbete dökme.

## Sık işler
- Mod tespiti: `scripts\windows\detect-device.ps1`
- Yedek: `backup-adb.ps1` (stok, usbdebug.html ile ADB) → `backup-edl.ps1` (EDL)
- Geri dönüş: `restore-edl.ps1 -Backup <dir> -Mode full` (GPT değiştiyse full şart)
- DTB: `scripts/linux/build-dtb.sh` (Linux/WSL; `KREF` çekirdek sürümüyle eşleşmeli, varsayılan `msm8916/6.12.1`)
- İmaj: Mio-sha512/OpenStick-Builder `debian` dalı + `builder/apply-hmuf02.sh`
- Cihazda: `scripts/linux/postinstall.sh <hostname> <ssid> <psk>`

## Windows notları
- PowerShell 5.1: `.ps1` dosyaları **UTF-8 BOM** ile kaydedilmeli (Türkçe karakterler), binary veriyi PowerShell boru hattından geçirme (`cmd /c ... > file` kullan).
- EDL için Zadig ile WinUSB (veya UsbDk). lk2nd fastboot için gerekirse WinUSB.

## Belgeler
`docs/00-hardware.md`, `docs/02-backup-restore.md`, `docs/03-debian-install.md`, `docs/04-ideas.md`. Yeni bir bulgu (pin, test noktası, sorun/çözüm) doğrulanınca ilgili belgeye ve `README.md` yol haritasına işle.
