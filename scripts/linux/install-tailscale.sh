#!/bin/sh
# Tailscale kurulumu (HMUF02 / Debian 13). Cihazda root olarak çalıştırın:
#
#   scp scripts/linux/install-tailscale.sh user@192.168.100.1:/tmp/
#   ssh user@192.168.100.1 sudo sh /tmp/install-tailscale.sh [hostname]
#
# Ekrana basılan https://login.tailscale.com/... linkini tarayıcıda açıp cihazı onaylayın.
#
# HMUF02'ye özel notlar (2026-11-07):
#   - Builder imajında /etc/resolv.conf, kurulu olmayan systemd-resolved'e kırık bir kısayol.
#     Tailscale MagicDNS'in yönetebilmesi için gerçek dosyaya çevrilir (127.0.0.1 = dnsmasq).
#   - Çekirdekte CONFIG_NETFILTER_XT_CONNMARK yok: "connmark" sağlık uyarısı beklenir.
#     Temel bağlantıyı etkilemez; exit node / subnet router gibi özellikleri kısıtlayabilir.
set -eu
HN="${1:-$(hostname)}"
[ "$(id -u)" -eq 0 ] || { echo "root olarak çalıştırın"; exit 1; }

. /etc/os-release
echo "[*] Tailscale deposu ($VERSION_CODENAME)"
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL "https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.noarmor.gpg" \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL "https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.tailscale-keyring.list" \
    -o /etc/apt/sources.list.d/tailscale.list
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tailscale

echo "[*] Otomatik güncellemelere Tailscale deposu"
cat > /etc/apt/apt.conf.d/51unattended-upgrades-tailscale <<'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Tailscale";
};
EOF

echo "[*] resolv.conf"
if [ -L /etc/resolv.conf ] && [ ! -e /etc/resolv.conf ]; then
    rm /etc/resolv.conf
    printf "# yerel dnsmasq (-> dnsproxy). Tailscale MagicDNS bunu yönetir.\nnameserver 127.0.0.1\n" > /etc/resolv.conf
    systemctl restart tailscaled
fi

echo "[*] tailscale up --hostname=$HN  (linki tarayıcıda onaylayın)"
tailscale up --hostname="$HN"
tailscale ip -4
tailscale status
