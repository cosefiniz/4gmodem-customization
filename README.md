# 4G Modem → Linux Mini PC (HMUF02-V05 / MSM8916)

Ucuz "4G LTE WIFI MODEM" USB dongle'ı, **Debian çalıştıran başsız (headless) bir mini Linux bilgisayara** çevirme projesi.
Hedef, Raspberry Pi Zero W benzeri bir kullanım. 4G/LTE tarafı kullanılmayacak.

| | |
|---|---|
| Kart | **HMUF02-V05** (`zbx002`), UFI001 ailesinin yeni revizyonu |
| SoC | Qualcomm **MSM8916** (Snapdragon 410), 4× Cortex-A53 64-bit |
| Bellek | SK hynix H9TQ32A4GTMC: **512 MB RAM + 4 GB eMMC** |
| Wi-Fi | WCN3620, 2.4 GHz 802.11n |
| Topluluk | [msm8916-mainline](https://github.com/msm8916-mainline) (lk2nd + mainline çekirdek), OpenStick-Builder fork'ları, postmarketOS/Nura `zhihe-generic` |

## Yol haritası

| # | Adım | Durum | Belge / script |
|---|---|---|---|
| 0 | Donanım tespiti (fotoğraflar, stok DTS) | ✅ | [docs/00-hardware.md](docs/00-hardware.md) |
| 1 | Araçlar: adb/fastboot, bkerler/edl | ✅ indirildi. `pip install` kullanıcı tarafından | [scripts/windows/setup-tools.ps1](scripts/windows/setup-tools.ps1) |
| 2 | Cihazı USB'de görmek | ✅ `05C6:9024`, ADB açık, geçici root alındı | [scripts/windows/detect-device.ps1](scripts/windows/detect-device.ps1) |
| 3a | **ADB tam yedek** (28 bölüm + tüm eMMC, hash'li) | ✅ 2026-11-07. Kritik bölümlerin hepsi doğrulandı | [docs/02-backup-restore.md](docs/02-backup-restore.md) |
| 3b | Yedeğin 2 ayrı yere kopyalanması | ⏳ kullanıcı | |
| 3c | EDL "soğuk" yedek (flaştan hemen önce) | ⏳ | [scripts/windows/backup-edl.ps1](scripts/windows/backup-edl.ps1) |
| 4 | HMUF02 device tree (doğru LED'ler, modem kapalı) | 📝 taslak | [dts/](dts/) |
| 5 | Debian 13 imajı derleme (Mio builder + HMUF02 yaması) | 📝 hazır, denenmedi | [builder/apply-hmuf02.sh](builder/apply-hmuf02.sh) |
| 6 | Flaşlama + ilk açılış | – | [docs/03-debian-install.md](docs/03-debian-install.md) |
| 7 | Yapılandırma (zram, modem kapalı, Wi-Fi, SSH) | 📝 script hazır | [scripts/linux/postinstall.sh](scripts/linux/postinstall.sh) |
| 8 | Kullanım senaryosu | – | [docs/04-ideas.md](docs/04-ideas.md) |

## Hızlı başlangıç

```powershell
# 1) Araçları kur (bir kez)
powershell -ExecutionPolicy Bypass -File scripts\windows\setup-tools.ps1

# 2) Cihaz hangi modda?
powershell -ExecutionPolicy Bypass -File scripts\windows\detect-device.ps1

# 3) Yedek: önce ADB (kolay), sonra EDL (tam)
powershell -ExecutionPolicy Bypass -File scripts\windows\backup-adb.ps1
powershell -ExecutionPolicy Bypass -File scripts\windows\backup-edl.ps1
```

## Repo yapısı

```
docs/            belgeler + cihaz fotoğrafları
dts/             HMUF02 device tree kaynakları (mainline msm8916-ufi.dtsi tabanlı)
builder/         OpenStick-Builder'ı HMUF02'ye uyarlayan yama scripti
scripts/windows/ yedek / geri yükleme / tespit (PowerShell)
scripts/linux/   DTB derleme, cihaz üzerinde postinstall
backups/         (git dışı) cihaz yedekleri: IMEI/MAC içerir, paylaşmayın
tools/           (git dışı) platform-tools
third_party/     (git dışı) edl, lk2nd, OpenStick-Builder fork'ları, referans DTS'ler
```

## Güvenlik kuralları

1. Yedek (EDL tam imaj + kritik bölümler) iki ayrı yere kopyalanmadan cihaza **hiçbir şey yazılmaz**.
2. `modemst1/2`, `fsg`, `fsc`, `persist` bu cihaza özeldir. Başka cihazın dökümü yerine geçmez.
3. tz ve hyp **birlikte** değişir. DB410c tz + stok hyp = açılmayan cihaz.
4. EDL (SoC ROM'unda) her zaman erişilebilir. Doğru yedekle her durumdan geri dönülebilir.

## Kaynaklar

- msm8916-mainline: [lk2nd](https://github.com/msm8916-mainline/lk2nd), [linux](https://github.com/msm8916-mainline/linux) (`msm8916/6.12.1`, `wip/msm8916/7.0`)
- Builder'lar: [Mio-sha512](https://github.com/Mio-sha512/OpenStick-Builder) (Debian stable/Ubuntu 24.04), [LongQT-sea](https://github.com/LongQT-sea/OpenStick-Builder), [kinsamanka](https://github.com/kinsamanka/OpenStick-Builder)
- [bkerler/edl](https://github.com/bkerler/edl): Qualcomm EDL/firehose aracı
- [postmarketOS wiki: Zhihe series LTE dongles](https://wiki.postmarketos.org/wiki/Zhihe_series_LTE_dongles_(generic-zhihe))
- [OpenWrt forumu: HMUF02-V05](https://forum.openwrt.org/t/help-adding-modem-support-for-hmuf02-v05/225828), [stok DTS gist](https://gist.github.com/hotfur/b4b6db670840267a459855f3094e774a)
- [Dmitry Brant: OpenStick on HMUF02](https://dmitrybrant.com/openstick): Debian kararlı çalışıyor, LED'ler çalışmıyor
- OpenWrt alternatifi: [lkiuyu/immortalwrt](https://github.com/lkiuyu/immortalwrt) (`msm89xx`)
