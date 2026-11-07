# Ne yapılabilir: öneriler

Cihazın güçlü yanları: 4 çekirdek 64-bit CPU, dahili eMMC, Wi-Fi, USB gadget ve neredeyse sıfır maliyet.
Zayıf yanları: 512 MB RAM, GPIO yok, tek USB portu.

## Önerilen ilk hedef: "USB'ye takılan Linux kutusu"

Debian + üç arayüz:
- **USB gadget (ECM/RNDIS + seri):** herhangi bir PC'ye takınca ağ üzerinden SSH ve seri konsol. Pi Zero'nun "USB OTG gadget" kullanımının birebir karşılığı.
- **Wi-Fi istemci:** evdeki ağa bağlanır, USB güç adaptörüyle bağımsız çalışır.
- **Tailscale/ZeroTier:** her yerden erişim (PC'nizde ZeroTier zaten var).

## Fikirler (zorluk sırasıyla)

| Fikir | Not | RAM |
|---|---|---|
| Her yerden erişilen SSH/ZeroTier/Tailscale düğümü | Ev ağına arka kapı, jump host | Düşük |
| Pi-hole / AdGuard Home | Ev ağı DNS reklam engelleyici | ~100 MB |
| WireGuard VPN sunucusu / istemcisi | Seyahat yönlendiricisi: wlan0 istemci, USB üzerinden NAT | Düşük |
| Seyahat yönlendiricisi (Wi-Fi AP + USB) | hostapd + NAT. Mio builder'da hazır `wifi-ap.sh` var | Düşük |
| MQTT broker (Mosquitto) + Node-RED hafif | Ev otomasyonu ara birimi. ESP32 cihazlarınızla iyi eşleşir | Orta |
| USB HID "akıllı klavye" / makro | Gadget-tools ile HID: PC'ye klavye gibi takılır, Wi-Fi'den komut alır | Düşük |
| USB mass storage + ağ | PC'ye flash disk gibi görünür, içeriği Wi-Fi'den güncellenir (yazıcı/CNC/3D yazıcı dosya aktarımı) | Düşük |
| Seri konsol sunucusu (ser2net) | USB-OTG ile başka bir cihazın UART'ını ağa aç (kısmi OTG + hub gerekir) | Düşük |
| Uptime Kuma / basit izleme | Ağdaki cihazları izle, Telegram bildirimi | Orta |
| Klipper ana bilgisayarı | 3D yazıcı. Bildirilen denemeler var, ama 512 MB RAM ile Mainsail sınırda | Yüksek |
| OpenWrt (lkiuyu/immortalwrt `msm89xx`) | Debian yerine. Router işlevi için daha uygun | – |

## Önerilmeyenler

- Masaüstü/GUI, Docker ağır yükler, Home Assistant tam kurulum: RAM yetmez.
- Sürekli yoğun yazma (veritabanı, log): eMMC ucuz ve muhtemelen geri dönüşüm. `postinstall.sh` journald'ı RAM'e alır.

## Donanım genişletme

- **UART (`RX0/TX0`)**: kalıcı seri konsol. Kabloyu lehimleyip kutudan dışarı alabilirsiniz.
- **Arka yüzdeki `GPIO`, `RX1/TX1` pedleri**: doğrulanırsa ikinci UART ve bir GPIO olur. Örneğin bir sensör ya da bir ESP32 ile haberleşme.
- **LED'ler (3 adet) ve tuş**: Linux'ta `/sys/class/leds` ve `gpio-keys` (KEY_RESTART) olarak kullanılabilir. Tuşa bir systemd/triggerhappy eylemi bağlanabilir (örn. Wi-Fi AP aç/kapat).
- USB OTG + hub ile harici cihaz: kısmi destek, harici besleme gerekebilir.
