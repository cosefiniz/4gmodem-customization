#!/usr/bin/env bash
# Bir OpenStick-Builder klonunu (Mio-sha512 debian dalı önerilir) HMUF02-V05 için uyarlar.
#
#   git clone --recurse-submodules -b debian https://github.com/Mio-sha512/OpenStick-Builder.git build/OpenStick-Builder
#   builder/apply-hmuf02.sh build/OpenStick-Builder            # varsayılan: modem kapalı dtb
#   DTB=msm8916-hmuf02 builder/apply-hmuf02.sh build/OpenStick-Builder
#   cd build/OpenStick-Builder && sudo ./build.sh
#
# Yaptıkları:
#   1. dts/ altındaki HMUF02 device tree'lerini derler, builder'ın dtbs/ klasörüne koyar
#   2. extlinux.conf'u HMUF02 dtb'sini kullanacak şekilde değiştirir (varsayılan uz801v3)
#   3. lk1st (aboot) derlemesinde LK2ND_COMPATIBLE değerini UFI001C ailesine çeker
#   4. builder'ın varsayılan Wi-Fi hotspot ve kullanıcı parolası için uyarı basar
set -euo pipefail

B="${1:?Kullanım: $0 <OpenStick-Builder dizini>}"
DTB="${DTB:-msm8916-hmuf02-nomodem}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$B/build.sh" ] || { echo "$B bir OpenStick-Builder dizini değil"; exit 1; }

echo "[1/3] DTB derleniyor"
"$ROOT/scripts/linux/build-dtb.sh"
cp "$ROOT"/build/dtbs/*.dtb "$B/dtbs/"

echo "[2/3] extlinux.conf -> $DTB.dtb"
sed -i -E "s#^fdt .*#fdt /dtbs/qcom/${DTB}.dtb#" "$B/configs/extlinux.conf"
grep '^fdt' "$B/configs/extlinux.conf"

echo "[3/3] lk1st LK2ND_COMPATIBLE -> thwc,ufi001c"
sed -i -E 's#LK2ND_COMPATIBLE="[^"]*"#LK2ND_COMPATIBLE="thwc,ufi001c"#' "$B/scripts/build_hyp_aboot.sh"
grep -o 'LK2ND_COMPATIBLE="[^"]*"' "$B/scripts/build_hyp_aboot.sh"

cat <<'EOF'

[+] Hazır. Kurulumdan sonra ilk iş:
    - varsayılan kullanıcı parolasını değiştirin (passwd)
    - hotspot SSID/parolasını değiştirin veya kapatın (nmcli con show)
    - scripts/linux/postinstall.sh'ı çalıştırın
EOF
