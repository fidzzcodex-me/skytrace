#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-skytrace-release.jks}"
ALIAS="${2:-skytrace}"

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool not found, install a JDK 17" >&2
  exit 1
fi

read -r -s -p "Keystore password: " STORE_PASS
echo
read -r -s -p "Key password (enter to reuse keystore password): " KEY_PASS
echo
KEY_PASS="${KEY_PASS:-$STORE_PASS}"

keytool -genkeypair \
  -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=SkyTrace, OU=Open Source, O=SkyTrace, L=Jakarta, C=ID"

base64 -w 0 "$OUT" > "$OUT.base64.txt" 2>/dev/null || base64 "$OUT" | tr -d '\n' > "$OUT.base64.txt"

echo "keystore: $OUT"
echo "base64 for KEYSTORE_BASE64: $OUT.base64.txt"
echo "alias for KEY_ALIAS: $ALIAS"
