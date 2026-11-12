#!/usr/bin/env bash
# ينشئ keystore للإصدار ويكتب android/key.properties.
# شغّله مرة واحدة على جهازك، واحتفظ بنسخة احتياطية من الملف وكلمات المرور
# (لو ضاع، مش هتقدر تحدّث التطبيق على نفس التوقيع).
set -euo pipefail
KS="${1:-$HOME/payrolls-release.jks}"
read -rsp "Keystore password: " PASS; echo
keytool -genkeypair -v -keystore "$KS" -alias payrolls -keyalg RSA -keysize 4096 \
  -validity 10000 -storepass "$PASS" -keypass "$PASS"
cat > "$(dirname "$0")/../android/key.properties" <<EOP
storeFile=$KS
storePassword=$PASS
keyAlias=payrolls
keyPassword=$PASS
EOP
echo "Done. android/key.properties is git-ignored."
