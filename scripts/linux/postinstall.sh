#!/bin/sh
# Debian kurulduktan sonra dongle üzerinde (root olarak) çalıştırılır.
# Cihazı "Raspberry Pi Zero W" benzeri, başsız (headless) bir Linux kutusuna çevirir.
#
#   scp scripts/linux/postinstall.sh user@192.168.100.1:/tmp/
#   ssh user@192.168.100.1 sudo sh /tmp/postinstall.sh <hostname> [wifi-ssid] [wifi-parola]
#
# Yaptıkları:
#   - hostname, saat dilimi, locale
#   - LTE modem yığınını kapatır (ModemManager, rmtfs, qrtr modem servisleri) -> RAM ve güç kazancı
#   - zram swap (512 MB RAM için kritik), journald'ı RAM'e alır (eMMC ömrü)
#   - Wi-Fi istemci bağlantısı (NetworkManager)
#   - SSH sertleştirme, otomatik güvenlik güncellemeleri
set -eu

HOSTNAME_NEW="${1:-pistick}"
WIFI_SSID="${2:-}"
WIFI_PSK="${3:-}"

[ "$(id -u)" -eq 0 ] || { echo "root olarak çalıştırın"; exit 1; }

echo "[*] hostname: $HOSTNAME_NEW"
hostnamectl set-hostname "$HOSTNAME_NEW"
grep -q "$HOSTNAME_NEW" /etc/hosts || echo "127.0.1.1 $HOSTNAME_NEW" >> /etc/hosts
timedatectl set-timezone Europe/Istanbul || true

echo "[*] paketler"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    zram-tools network-manager openssh-server ca-certificates curl \
    htop nano less unattended-upgrades i2c-tools usbutils

echo "[*] LTE / modem servislerini devre dışı bırak (4G kullanılmayacak)"
for s in ModemManager rmtfs qmi-proxy; do
    systemctl disable --now "$s" 2>/dev/null || true
    systemctl mask "$s" 2>/dev/null || true
done
nmcli con delete lte 2>/dev/null || true
# Not: MSM8916'da Wi-Fi (WCNSS/wcn36xx) modemden (MPSS) ayrı bir çekirdekte çalışır.
# HMUF02'de modem kapalı DTB ile Wi-Fi'nin çalıştığı doğrulandı (2026-11-07).

echo "[*] Builder'ın açık hotspot'unu kapat (parolası herkese açık reposunda yazıyor)"
systemctl disable --now hostapd 2>/dev/null || true

echo "[*] nftables: çekirdekte CONFIG_NFT_REDIR yok; DNS 'redirect' kuralları tüm dosyanın yüklenmesini engelliyor"
if grep -q 'redirect to' /etc/nftables.conf 2>/dev/null; then
    cp -n /etc/nftables.conf /etc/nftables.conf.orig
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
# HMUF02 / 4gmodem-customization. Orijinali: /etc/nftables.conf.orig
# DNS "redirect" kuralları kaldırıldı (çekirdekte CONFIG_NFT_REDIR yok). Sadece LAN NAT.
flush ruleset

table ip nat {
	chain postrouting {
		type nat hook postrouting priority 100;
		ip saddr 192.168.100.0/24 ip daddr != 192.168.100.0/24 masquerade
	}
}

table ip6 nat {
	chain postrouting {
		type nat hook postrouting priority 100;
		ip6 saddr dead:beef::/64 ip6 daddr != dead:beef::/64 masquerade
	}
}
EOF
    systemctl restart nftables || true
fi
systemctl reset-failed || true

echo "[*] zram swap"
cat > /etc/default/zramswap <<'EOF'
ALGO=zstd
PERCENT=75
PRIORITY=100
EOF
systemctl enable --now zramswap

echo "[*] journald -> RAM (eMMC yıpranmasını azaltır)"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/volatile.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=16M
EOF
systemctl restart systemd-journald

echo "[*] /tmp -> tmpfs"
systemctl enable tmp.mount 2>/dev/null || true

if [ -n "$WIFI_SSID" ]; then
    echo "[*] Wi-Fi istemcisi: $WIFI_SSID"
    nmcli radio wifi on
    nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PSK" || \
        echo "!! Wi-Fi bağlanamadı; 'nmcli dev wifi list' ile kontrol edin"
fi

echo "[*] SSH: parola ile root girişini kapat (önce anahtarınızı ekleyin!)"
if [ -s /root/.ssh/authorized_keys ]; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    systemctl reload ssh
else
    echo "!! /root/.ssh/authorized_keys boş; SSH ayarı değiştirilmedi."
fi

dpkg-reconfigure -f noninteractive unattended-upgrades

echo "[+] Bitti. 'free -h', 'zramctl', 'nmcli' ile kontrol edin."
