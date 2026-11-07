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

1. Dongle'ı takın. Windows'ta "Remote NDIS" ağ adaptörü ve "ADB Interface" belirir (USB `05C6:9024`), dongle `192.168.100.1` olur.
   Bu cihazda ADB **varsayılan açık**. Başka sürümlerde `http://192.168.100.1/usbdebug.html` sayfası açar.
2. **Başka ADB sunucularını kapatın.** Bu bilgisayarda **SuperDisplay** hizmeti kendi eski ADB'sini (1.0.40) yönetici olarak çalıştırıyor ve dongle'ı sahipleniyor.
   Yedekten önce durdurun (Hizmetler → SuperDisplay → Durdur), sonra `tools\platform-tools\adb.exe kill-server`. `detect-device.ps1` bu durumu uyarır.
3. `tools\platform-tools\adb.exe devices` cihazı göstermeli.
4. Yedeği alın. Script root'u kendisi alır: `adb root` parola istediği için `setprop service.adb.root 1; busybox killall adbd` kullanır. Bu kalıcı değildir.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\backup-adb.ps1
```

Çıktı `backups\adb-<tarih>\` altına gider:
- `parts\*.bin`: 28 bölümün her biri
- `full\mmcblk0.bin`: GPT dahil tüm eMMC
- `info\*`: getprop, cpuinfo, bölüm listesi, ofsetler
- `MD5SUMS.txt` ve `SHA256SUMS.txt`

Her bölümün MD5'i cihazdakiyle karşılaştırılır. Yaklaşık 15 dakika sürer ve 7.1 GB yer kaplar.

**Sistem çalışırken alınan yedeğin sınırı:** çalışan modem `modemst1/2` bölümlerini sürekli yeniden yazar. Android de `cache`/`userdata`'ya yazar.
Bu yüzden `parts\` içindeki kopyalar kendi anlarında doğrulanmıştır, ama `full\mmcblk0.bin` içindeki aynı bölgeler birkaç dakika sonraki hallerini içerir.
Stoka dönüşte önce tam imaj, sonra `parts\` içinden kritik bölümler yazılmalıdır.
Flaşlamadan hemen önce EDL'de (modem kapalıyken) "soğuk" bir yedek almak yine de en iyisidir.

### İlk yedek: 2026-11-07 (`backups\adb-20261107-152754`)

- 26/28 bölüm cihazla birebir doğrulandı (`cache`, `userdata` hariç).
- Kritik bölümlerin hepsi OK: `modem`, `modemst1`, `modemst2`, `fsg`, `fsc`, `persist`, `sec`, `sbl1`, `aboot`, `rpm`, `tz`, `hyp`.
- Tam imaj, ayrı bölümlerle karşılaştırıldı:
  - `system`: sadece ext4 süper bloğu farklı (zararsız).
  - `modemst1/2`: modem yeniden yazmış.
  - `cache`, `userdata`: Android yazıyor.
  - Geri kalan her şey birebir aynı.

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

### HMUF02'de doğrulanan EDL ayrıntıları (2026-11-07)

- **EDL'e giriş: tuş yöntemi çalışıyor.** SIM yanındaki tuşa basılı tutup USB'ye takın. LED'ler sönük kalır ve cihaz `QHSUSB__BULK` (05C6:9008) olarak görünür.
  Stok yazılım `adb reboot edl` komutunu yok sayar (normal açılır, `05C6:9091`).
- **Sürücü:** winget Zadig'i Başlat menüsüne eklemez. Şununla açın:
  `Start-Process "$env:LOCALAPPDATA\Microsoft\WinGet\Links\zadig.exe" -Verb RunAs`
  Ardından Options → List All Devices → `QHSUSB__BULK` → WinUSB.
- **Loader:** edl otomatik buluyor (`Loaders/cyanogen/007050e100000000_4614048173062ae4_fhprg_peek.bin`). `getstorageinfo` desteklenmiyor, zararsız.
- **`.venv\Scripts\edl.exe` Windows'ta çalışmaz:** `edlclient\edl.py` sembolik bağlantı. Scriptler `python third_party\edl\edl.py` kullanır.
- **Soğuk yedek:** `backups\edl-20261107-163352`
  - 28/28 bölüm tam imajla birebir.
  - ADB yedeğine göre farklı olanlar: `modemst1/2` (modem yazmış), `persist` (7 blok ext4 meta/journal), `system` (süper blok), `cache`, `userdata`.
  - Flaşlamada cihaza özel bölümler **bu** yedekten yazılır.

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
