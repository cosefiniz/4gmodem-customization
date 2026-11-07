#!/usr/bin/env bash
# Bir OpenStick-Builder klonunu (Mio-sha512 debian dalı) HMUF02-V05 için uyarlar.
# GitHub Actions'ta .github/workflows/build-image.yml tarafından çağrılır; yerelde de çalışır:
#
#   git clone --recurse-submodules -b debian https://github.com/Mio-sha512/OpenStick-Builder.git build/OpenStick-Builder
#   builder/apply-hmuf02.sh build/OpenStick-Builder            # varsayılan: modem kapalı dtb
#   DTB=msm8916-hmuf02 builder/apply-hmuf02.sh build/OpenStick-Builder
#   cd build/OpenStick-Builder && sudo ./build.sh
#
# Yaptıkları:
#   1. dts/ altındaki HMUF02 device tree'lerini derler, builder'ın dtbs/ klasörüne koyar
#   2. extlinux.conf'u HMUF02 dtb'sini kullanacak şekilde değiştirir (varsayılan uz801v3)
#   3. lk2nd'ye "zbx,hmuf02" girdisi ekler ve lk1st'i bu uyumlulukla derletir.
#      Neden: lk2nd'nin "thwc,ufi001c" girdisi GPIO 37 tuşunu AKTİF-DÜŞÜK tanımlıyor;
#      HMUF02 stok DTS'si (ve mainline ufi001c) AKTİF-YÜKSEK diyor. lk2nd bu tuşu
#      açılışta basılı görürse her seferinde fastboot'a düşer.
set -euo pipefail

B="${1:?Kullanım: $0 <OpenStick-Builder dizini>}"
DTB="${DTB:-msm8916-hmuf02-nomodem}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LK_DTS="$B/src/lk2nd/lk2nd/device/dts/msm8916/msm8916-512mb-mtp.dts"

[ -f "$B/build.sh" ] || { echo "$B bir OpenStick-Builder dizini değil"; exit 1; }
[ -f "$LK_DTS" ]     || { echo "lk2nd kaynağı yok: $LK_DTS (submodule'ler indirildi mi?)"; exit 1; }

echo "[1/4] DTB derleniyor"
"$ROOT/scripts/linux/build-dtb.sh"
cp "$ROOT"/build/dtbs/*.dtb "$B/dtbs/"
ls -la "$B/dtbs/"

echo "[2/4] extlinux.conf -> $DTB.dtb"
sed -i -E "s#^fdt .*#fdt /dtbs/qcom/${DTB}.dtb#" "$B/configs/extlinux.conf"
grep -q "^fdt /dtbs/qcom/${DTB}.dtb" "$B/configs/extlinux.conf"
cat "$B/configs/extlinux.conf"

echo "[3/4] lk2nd'ye zbx,hmuf02 girdisi"
if ! grep -q 'zbx,hmuf02' "$LK_DTS"; then
    python3 - "$LK_DTS" "$DTB" <<'PY'
import sys
path, dtb = sys.argv[1], sys.argv[2]
node = f'''
	zbx-hmuf02 {{
		model = "HMUF02-V05 4G Modem Stick";
		compatible = "zbx,hmuf02";

		/* lk1st ile: LK2ND_COMPATIBLE="zbx,hmuf02" */
		lk2nd,dtb-files = "{dtb}";

		gpio-keys {{
			compatible = "gpio-keys";
			edl {{
				/* Tek tuş. Stok DTS: GPIO 37, aktif-yüksek */
				lk2nd,code = <KEY_HOME>;
				gpios = <&tlmm 37 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>;
			}};
		}};
	}};
'''
src = open(path).read()
anchor = '&lk2nd {\n'
assert anchor in src, 'lk2nd düğümü bulunamadı'
src = src.replace(anchor, anchor + node, 1)
open(path, 'w').write(src)
PY
fi
grep -n -A4 'zbx-hmuf02' "$LK_DTS"

echo "[4/4] lk1st LK2ND_COMPATIBLE -> zbx,hmuf02"
sed -i -E 's#LK2ND_COMPATIBLE="[^"]*"#LK2ND_COMPATIBLE="zbx,hmuf02"#' "$B/scripts/build_hyp_aboot.sh"
grep -q 'LK2ND_COMPATIBLE="zbx,hmuf02"' "$B/scripts/build_hyp_aboot.sh"

cat <<'EOF'

[+] Hazır. Kurulumdan sonra ilk iş:
    - varsayılan kullanıcı parolasını değiştirin (passwd)
    - hotspot SSID/parolasını değiştirin veya kapatın (nmcli con show)
    - scripts/linux/postinstall.sh'ı çalıştırın
EOF
