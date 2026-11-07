# Debian kurulumu

> Ön koşul: [02-backup-restore.md](02-backup-restore.md) içindeki **EDL tam yedeği** alınmış ve iki ayrı yere kopyalanmış olmalı.

## Mimari: neler değişiyor

```
Stok:    sbl1 → tz/hyp/rpm (stok) → aboot (Android LK) → boot (Android 4.4 çekirdeği) → Android/OpenWrt benzeri stok sistem
Debian:  sbl1 → tz/rpm (DB410c) + hyp (qhypstub) → aboot = lk1st (lk2nd) → extlinux.conf → mainline Linux 6.12 → Debian
```

- **lk2nd / lk1st**: msm8916-mainline'ın bootloader'ı. `aboot` bölümüne "lk1st" olarak yazılır, fastboot sağlar ve `extlinux.conf` okur.
- **qhypstub + DB410c tz/rpm/sbl1**: mainline çekirdek için gerekli. **tz ve hyp birlikte değişmeli.** DB410c tz'si stok hyp ile karışırsa cihaz açılmaz.
- **GPT değişir**: rootfs tüm eMMC'yi kullanır (`gpt_both0.bin`).
- `modem`, `persist`, `modemst*`, `fsg`, `fsc`, `sec` yedekten geri yazılır. `msm-firmware-loader` Wi-Fi firmware'ini bu bölümlerden otomatik bağlar.

## Hangi imaj

| Seçenek | Debian | Durum | Öneri |
|---|---|---|---|
| [Mio-sha512/OpenStick-Builder](https://github.com/Mio-sha512/OpenStick-Builder) `debian` dalı | stable (= **13 trixie**) | Aktif, CI ile derleniyor, CPR yamalı 6.12.1 çekirdek | **Önerilen** |
| [LongQT-sea/OpenStick-Builder](https://github.com/LongQT-sea/OpenStick-Builder) | 12 bookworm | Hazır release (v1.2) var | Hızlı deneme için |
| [kinsamanka/OpenStick-Builder](https://github.com/kinsamanka/OpenStick-Builder) | stable | Asıl kaynak, 6.6 çekirdek | Referans |
| [OpenStick/OpenStick](https://github.com/OpenStick/OpenStick) | 11 | 2022'den beri durgun | Kullanmayın |
| postmarketOS (Nura) `zhihe-generic` | Alpine | Aktif | Debian değil, ama en iyi upstream desteği |

Bu repo Mio builder'ını temel alır ve HMUF02 için üç şeyi değiştirir ([builder/apply-hmuf02.sh](../builder/apply-hmuf02.sh)):
1. LED pinleri doğru olan HMUF02 device tree'si ([dts/](../dts/)). Hazır imajlarla HMUF02'de "her şey çalışıyor ama LED'ler yanmıyor" raporunun sebebi bu.
2. Varsayılan olarak **modem kapalı** dtb: 4G kullanmıyoruz ve bu ~90 MB RAM kazandırır.
3. lk1st'in uyumluluk dizesi UFI001C ailesine çekilir.

## İmajı derleme

Derleme Linux gerektirir. İki yol var:

**A) GitHub Actions (önerilen, PC'ye bir şey kurmadan):**

Bu repodaki [.github/workflows/build-image.yml](../.github/workflows/build-image.yml) şunları yapar:
1. Mio builder'ı sabit bir commit'te alır.
2. `builder/apply-hmuf02.sh` ile yamalar: HMUF02 DTB'leri, extlinux ve lk2nd `zbx,hmuf02` girdisi (GPIO 37 aktif-yüksek tuş).
3. ARM runner'da derler.
4. `hmuf02-debian-<no>` artifact'ini 30 gün saklar.

`dts/` veya `builder/` değişince kendiliğinden çalışır. Elle çalıştırmak için:
```bash
gh workflow run build-image.yml -f dtb=msm8916-hmuf02-nomodem
gh run watch
gh run download --name hmuf02-debian-<no> --dir build/image
```

**B) WSL2 (Ubuntu 24.04):**
```bash
wsl --install -d Ubuntu-24.04          # Windows tarafında, bir kez
# Ubuntu içinde, repo dizininde:
sudo apt install -y git cpp device-tree-compiler
git clone --recurse-submodules -b debian https://github.com/Mio-sha512/OpenStick-Builder.git build/OpenStick-Builder
builder/apply-hmuf02.sh build/OpenStick-Builder
cd build/OpenStick-Builder && sudo ./build.sh
```
Çıktılar `build/OpenStick-Builder/files/` altına düşer: `aboot.mbn`, `hyp.mbn`, `rpm.mbn`, `sbl1.mbn`, `tz.mbn`, `gpt_both0.bin`, `boot.bin`, `rootfs.bin`.

## Flaşlama (Windows'tan)

Önerilen yol: [scripts/windows/flash-debian.ps1](../scripts/windows/flash-debian.ps1). Script iki aşamalıdır: `-Stage edl`, ardından `-Stage fastboot`.
Aşağıdaki elle komutlar referans içindir.

HMUF02'de 2026-11-07'de doğrulananlar:
- `edl e boot` hata vermeden **hiçbir şey yapmıyor**. boot'u silmek için 16 MB sıfır yazılır (script bunu yapar).
- `edl reset` `--memory` seçeneğini kabul etmez.
- lk1st fastboot (`18D1:D00D`) bu PC'de ek sürücü gerektirmedi.
  `fastboot getvar all` çıktısında `lk2nd:compatible: zbx,hmuf02` görünür.
- rootfs yazımı ~7 dakika sürer.

Tüm komutlar repo kökünden. `F` = imaj dosyalarının klasörü, `BK` = EDL yedeğinizin `parts` klasörü.

```powershell
$edl = ".venv\Scripts\edl.exe"; $fb = "tools\platform-tools\fastboot.exe"
$F = "build\OpenStick-Builder\files"; $BK = "backups\edl-YYYYMMDD-HHMMSS\parts"

# 1) Cihaz EDL'de. lk1st'i aboot'a yaz, boot'u sil, yeniden başlat -> fastboot'a düşer
& $edl w aboot "$F\aboot.mbn"
& $edl e boot
& $edl reset

# 2) fastboot (lk2nd) -> Aygıt Yöneticisi'nde 18D1:D00D. Gerekirse Zadig ile WinUSB.
& $fb devices
& $fb flash partition "$F\gpt_both0.bin"
& $fb flash aboot "$F\aboot.mbn"
& $fb flash hyp   "$F\hyp.mbn"
& $fb flash rpm   "$F\rpm.mbn"
& $fb flash sbl1  "$F\sbl1.mbn"
& $fb flash tz    "$F\tz.mbn"
& $fb flash boot  "$F\boot.bin"
& $fb flash rootfs "$F\rootfs.bin"

# 3) Cihaza özel bölümleri KENDİ yedeğinden geri yaz
foreach ($n in 'fsc','fsg','modem','modemst1','modemst2','persist','sec') { & $fb flash $n "$BK\$n.bin" }

& $fb reboot
```

## İlk açılış

- USB ağ: Windows'ta "Remote NDIS Compatible Device" belirir (USB `1D6B:0104`, ayrıca seri COM portu ve depolama).
  Mio builder'da cihaz **192.168.100.1** adresindedir, PC DHCP ile 192.168.100.10–99 arası bir adres alır.
  (kinsamanka builder'ında 192.168.5.1.)
- Wi-Fi hotspot: Mio builder'da SSID "4G-UFI-XX". Parolası `configs/hostapd.conf` içinde ve herkesçe bilinir, **değiştirin veya kapatın**.
- Seri konsol: `RX0/TX0/GND`, 115200 (bkz. [00-hardware.md](00-hardware.md)).
- Varsayılan giriş: `user` / `1`. **İlk iş değiştirin.**

```bash
ssh user@192.168.100.1
sudo passwd user && sudo passwd root
sudo resize2fs /dev/disk/by-partlabel/rootfs     # builder zaten yapmadıysa
cat /proc/device-tree/model                       # "HMUF02-V05 ..." görmelisiniz
free -h                                           # nomodem dtb ile ~450 MB+ toplam
nmcli dev wifi list                               # Wi-Fi çalışıyor mu
ls /sys/class/leds/                               # LED testi: echo 1 > .../brightness
```

Sonra yapılandırma scripti:
```bash
scp scripts/linux/postinstall.sh user@192.168.100.1:/tmp/
ssh user@192.168.100.1 sudo sh /tmp/postinstall.sh pistick "<ev-wifi-ssid>" "<parola>"
```

## Sorun giderme

| Belirti | Olası sebep / çözüm |
|---|---|
| Açılmıyor, USB'de hiçbir şey yok | tz/hyp uyumsuz. EDL'e girin (tuş) ve `restore-edl.ps1 -Mode full` |
| fastboot'ta kalıyor | `boot`/`rootfs` yazılmamış veya extlinux.conf'taki dtb adı yanlış |
| Wi-Fi yok | `modem`/`persist` geri yazılmamış. `dmesg \| grep -i wcn` ile bakın; nomodem dtb şüpheliyse `msm8916-hmuf02.dtb`'ye dönün |
| Rastgele eMMC hataları | Builder HS200'e düşürüyor. Yine olursa daha düşük hız gerekebilir |
| LED'ler ters renk | `dts/msm8916-hmuf02.dts` içinde led_r/g/b GPIO'larını değiştirin, yeniden derleyin |

## Uzaktan erişim: Tailscale

```bash
scp scripts/linux/install-tailscale.sh user@192.168.100.1:/tmp/
ssh user@192.168.100.1 sudo sh /tmp/install-tailscale.sh openstick
```

Ekrandaki `https://login.tailscale.com/...` linkini açıp cihazı onaylayın.
Sonra Tailscale kurulu her cihazdan `ssh user@openstick` ile her yerden bağlanabilirsiniz (MagicDNS).

HMUF02 notları (2026-11-07, Tailscale 1.104.5):
- Builder imajında `/etc/resolv.conf` kırık bir kısayol (`systemd-resolved` kurulu değil). Script bunu gerçek dosyaya çevirir; ardından Tailscale DNS'i yönetir.
- `connmark` sağlık uyarısı beklenir: çekirdekte `CONFIG_NETFILTER_XT_CONNMARK` yok. Temel bağlantı çalışır.
- tailscaled ~38 MB RAM kullanır.
- Tailscale deposu otomatik güncellemelere eklidir.
- Öneri: Tailscale yönetim panelinde cihaz için **"Disable key expiry"** seçin. Yoksa 180 günde bir yeniden giriş ister.
