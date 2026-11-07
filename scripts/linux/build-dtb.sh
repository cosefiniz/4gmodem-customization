#!/usr/bin/env bash
# dts/*.dts dosyalarını .dtb'ye derler. Linux veya WSL2'de çalışır.
#
#   sudo apt install -y git cpp device-tree-compiler
#   scripts/linux/build-dtb.sh                      # varsayılan: msm8916/6.12.1
#   KREF=wip/msm8916/7.0 scripts/linux/build-dtb.sh # başka çekirdek dalı
#
# KREF, cihazda çalışan çekirdekle aynı sürüm olmalı (OpenStick-Builder Mio/LongQT
# postmarketOS linux-postmarketos-qcom-msm8916 6.12.1 kullanır).
set -euo pipefail

KREF="${KREF:-msm8916/6.12.1}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KSRC="$ROOT/build/linux-dts-${KREF//\//_}"
OUT="$ROOT/build/dtbs"

if [ ! -d "$KSRC/.git" ]; then
    echo "[*] msm8916-mainline/linux ($KREF) yalnızca DTS kısmı indiriliyor..."
    git clone --depth 1 --filter=blob:none --sparse -b "$KREF" \
        https://github.com/msm8916-mainline/linux.git "$KSRC"
    # include/uapi/linux: dt-bindings/input/linux-event-codes.h oraya sembolik bağlantı
    git -C "$KSRC" sparse-checkout set \
        arch/arm64/boot/dts/qcom include/dt-bindings include/uapi/linux scripts/dtc/include-prefixes
fi

QCOM="$KSRC/arch/arm64/boot/dts/qcom"
mkdir -p "$OUT"
cp "$ROOT"/dts/*.dts "$QCOM/"

for dts in "$ROOT"/dts/*.dts; do
    name="$(basename "$dts" .dts)"
    echo "[*] $name.dtb"
    cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
        -I "$KSRC/include" -I "$QCOM" -I "$KSRC/scripts/dtc/include-prefixes" \
        "$QCOM/$name.dts" -o "$OUT/$name.dts.tmp"
    dtc -@ -q -I dts -O dtb -o "$OUT/$name.dtb" "$OUT/$name.dts.tmp"
    rm -f "$OUT/$name.dts.tmp"
done

ls -la "$OUT"
echo "[+] Cihaza kopyalayın: scp build/dtbs/*.dtb root@<ip>:/boot/dtbs/qcom/"
echo "    ve /boot/extlinux/extlinux.conf içindeki 'fdt' satırını güncelleyin."
