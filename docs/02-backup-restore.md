# Yedekleme ve geri yükleme

> **Kural:** Yedek alınıp en az iki ayrı yere kopyalanmadan ve hash'leri doğrulanmadan cihaza **hiçbir şey yazılmaz.**

## Neden önemli

Bazı bölümler **bu cihaza özeldir**. İnternetten indirilen bir stok imaj bunların yerini tutmaz:

| Bölüm | İçerik | Kaybolursa |
|---|---|---|
| `modemst1`, `modemst2`, `fsg`, `fsc` | Modem EFS/NV: IMEI, RF kalibrasyonu | IMEI ve LTE kalıcı olarak gider |
| `persist` | `WCNSS_qcom_wlan_nv.bin`: Wi-Fi kalibrasyonu, MAC | Wi-Fi zayıf çalışır veya hiç çalışmaz |
| `modem` | Modem + **Wi-Fi firmware'i** (`wcnss.mdt/.b*`) | Debian'da Wi-Fi çalışmaz |
| `sec` | Güvenlik ayarları | Stoka dönüş sorunlu olur |
| `sbl1`, `aboot`, `rpm`, `tz`, `hyp` | Önyükleme zinciri | Stoka dönülemez |

4G'yi kullanmayacak olsak bile `modem` ve `persist` Wi-Fi için **zorunlu**. Diğerleri de stoka dönebilmek için gerekli.

## Araçlar (bir kez)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\setup-tools.ps1
```

Bu komut `tools\platform-tools` (adb/fastboot), `third_party\edl` (bkerler/edl) ve `.venv` kurar.

**EDL sürücüsü (Windows):** cihaz EDL'deyken Aygıt Yöneticisi'nde `QUSB__BULK` (VID 05C6, PID 9008) görünür.
[Zadig](https://zadig.akeo.ie) ile bu aygıta **WinUSB** kurun (`winget install akeo.ie.Zadig`).
bkerler/edl README'si alternatif olarak [UsbDk](https://github.com/daynix/UsbDk/releases) önerir.

## Adım 0: Cihazın durumunu tespit et

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\detect-device.ps1
```

## Yol A: ADB ile hızlı yedek (kutu açılmadan)

1. Dongle'ı takın. Windows'ta bir RNDIS ağ adaptörü belirmeli ve dongle `192.168.100.1` (bazı sürümlerde `192.168.0.1`) olmalı.
   Dongle'ın Wi-Fi yayınına da bağlanabilirsiniz.
2. Tarayıcıda `http://192.168.100.1/usbdebug.html` adresini açın (bazı sürümlerde `usb_debug.html`). Bu sayfa ADB'yi açar.
3. `tools\platform-tools\adb.exe devices` cihazı göstermeli.
4. Root gerekiyorsa: `adb shell "setprop service.adb.root 1; busybox killall adbd"`, sonra tekrar `adb devices`.
5. Yedeği alın:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\backup-adb.ps1
```

Çıktı `backups\adb-<tarih>\` altına gider: `parts\*.bin`, `info\*` (getprop, cpuinfo, bölüm listesi, stok DTS bilgisi) ve `MD5SUMS.txt`.
Her bölümün hash'i cihazdakiyle karşılaştırılır.

## Yol B: EDL ile tam yedek (altın standart)

EDL'e girme yolları:
- ADB çalışıyorsa: `tools\platform-tools\adb.exe reboot edl`
- Dongle takılı değilken karttaki tuşa basılı tutun, USB'ye takın, 2–3 sn sonra bırakın (UFI kartlarda tuş = EDL).
- Olmazsa: EDL test noktasını GND'ye kısa devre ederek takmak. HMUF02'de yeri henüz doğrulanmadı. Gerekirse arka yüzün yüksek çözünürlüklü fotoğrafıyla birlikte araştırırız.

EDL'de iken:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\backup-edl.ps1
```

Alınanlar:
- `gpt\`: bölüm tablosu
- `parts\`: her bölüm ayrı + `rawprogram0.xml`
- `full\emmc_full.bin`: tüm eMMC'nin birebir kopyası (~4 GB). Hızlı deneme için `-SkipFull` kullanılabilir, ama asıl yedekte **atlamayın**.
- `SHA256SUMS.txt`

Cihazı EDL'den çıkarmak için: `.venv\Scripts\edl.exe reset`

## Yedeği saklama

- `backups\` klasörü `.gitignore`'da. **Repoya ve herkese açık yerlere koymayın**: IMEI ve MAC içerir.
- En az iki kopya tutun: harici disk + şifreli arşiv (örn. 7-Zip AES-256) ile bulut.

## Geri yükleme (stoka dönüş)

```powershell
# Bölüm bölüm (önerilen)
powershell -ExecutionPolicy Bypass -File scripts\windows\restore-edl.ps1 -Backup backups\edl-YYYYMMDD-HHMMSS -Mode parts
# Tüm eMMC (son çare: GPT değiştirildiyse bu gerekir)
powershell -ExecutionPolicy Bypass -File scripts\windows\restore-edl.ps1 -Backup backups\edl-YYYYMMDD-HHMMSS -Mode full
```

> OpenStick kurulumu **GPT'yi değiştirir** (`gpt_both0.bin`). Bu yüzden Debian'dan stoka dönerken `-Mode full` en güvenli yoldur.
> `parts` modu sadece bölüm tablosu aynıysa doğru çalışır.

EDL her zaman erişilebilir olduğu için (SoC'nin ROM'unda), yanlış bir yazma sonrası bile bu yedekle geri dönülebilir.
