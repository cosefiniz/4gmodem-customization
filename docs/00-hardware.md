# Donanım: HMUF02-V05 MSM8916 4G USB dongle

Fotoğraflar: [photos/](photos/)

## Tespit edilenler (fotoğraflardan)

| Parça | İşaret | Anlamı |
|---|---|---|
| SoC | Qualcomm **MSM8916** 6VV / AK627QHP | Snapdragon 410: 4× Cortex-A53 64-bit, ~1.0–1.2 GHz, Adreno 306, modem dahili |
| Bellek | SK hynix **H9TQ32A4GTMC** | eMCP: 4 GB eMMC + 512 MB LPDDR3 |
| RF | Qualcomm **WTR1605L** | LTE alıcı-verici (kullanmayacağız) |
| Wi-Fi/BT | WCN3620 (SoC içi WCNSS çekirdeği) | 2.4 GHz 802.11n + BT 4.x |
| PMIC | PM8916 | Güç yönetimi |
| Kart | `HMUF02-V05`, `zbx002 E465280` | UFI001 ailesinin yeni revizyonu |
| SIM | Tam boy SIM yuvası | Kullanılmayacak |

## Kart üzerindeki test noktaları

Ön yüz (USB fişinin olduğu taraf, SIM yuvası tarafı):

- **`RX0` `TX0` `GND`**: Seri konsol (UART, `ttyMSM0`, **115200 8N1**, **3.3 V**).
  Bir USB-TTL çeviriciyle (örn. sizdeki CH340K) bağlanabilirsiniz: dongle TX0 → çevirici RX, RX0 → TX, GND → GND.
  **VCC bağlamayın**: dongle zaten USB'den beslenir.
  lk2nd/çekirdek açılış mesajlarını görmek ve ağ bozulduğunda kurtarmak için en değerli araç budur.
- `VBAT` `GND`: pil girişi. Kullanılmıyor.
- Tek tuş (SIM yuvasının yanında): **GPIO 37**. Stokta "reset" tuşu. UFI kartlarda bu tuş aynı zamanda **EDL tuşu** olarak geçer: tuşa basılıyken USB'ye takmak EDL'e sokar. HMUF02'de doğrulanmadı.

Arka yüz (SoC tarafı): `GPIO`, `RX1`, `TX1` etiketli küçük pedler var. İkinci UART (blsp_uart1) ve bir GPIO olabilir; doğrulanmadı.

## Stok device tree'den çıkan pinler

Kaynak: [OpenWrt forumu HMUF02 başlığı](https://forum.openwrt.org/t/help-adding-modem-support-for-hmuf02-v05/225828) ve
[stok DTS](https://gist.github.com/hotfur/b4b6db670840267a459855f3094e774a). Yerel kopyası `third_party/dts-ref/hmuf02-stock.dts` içinde.

| İşlev | GPIO | UFI001C | UF896 |
|---|---|---|---|
| Tuş (key_freset) | 37 (aktif-yüksek) | 37 | 35 |
| LED `4g_1` | 71 | 20 | 81 |
| LED `4g_type` | 72 | 21 | 82 |
| LED `wifistatus` | 73 | 22 | 83 |
| `ftest` | 106 | – | – |
| eSIM seçimi | 119 / 14 / 12 | 0 / 1 / 2 / 3 | – |
| SIM hotplug | 114 | – | – |

Stok board-id `<8 0x100>`, model "MSM 8916 512MB MTP". Stok DTS'de `st7735s_128128` panel girdisi var, yani lk2nd bu kartı
"zhihe-various" (UFI001B/C, UFI003, MF601) olarak tanımalı. Bu bir çıkarım; test edilmedi.

> Kendi cihazınızın stok DTS'si yedek alınırken `backups/adb-*/info/compatible.txt` içine kaydedilir.
> Yukarıdaki pinleri kendi dökümünüzle karşılaştırın.

## Sınırlar (Raspberry Pi Zero W'ye göre)

| | Bu dongle | Pi Zero W |
|---|---|---|
| CPU | 4× A53 64-bit ~1.2 GHz | 1× ARM11 32-bit 1 GHz |
| RAM | 512 MB | 512 MB |
| Depolama | 4 GB eMMC (dahili, ~3.5 GB kullanılabilir) | microSD |
| Wi-Fi | 2.4 GHz n | 2.4 GHz n |
| USB | 1× (device/gadget, kısmi OTG) | 1× OTG |
| GPIO | Yok (birkaç ped) | 40 pin header |
| Kamera/ekran | Yok | CSI / mini-HDMI |
| Fiyat | çok ucuz | – |

Kısacası işlemci gücü Pi Zero W'den belirgin şekilde iyi. GPIO/donanım arayüzü açısından ise zayıf.
En iyi uyduğu iş: **ağ odaklı, başsız (headless) küçük sunucu** ve **USB gadget** cihazı.
