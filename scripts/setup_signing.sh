#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

JKS="android/app/release.jks"
PROPS="android/key.properties"
ENC="android/signing/skytrace.keystore.enc"
ALIAS="${KEY_ALIAS:-skytrace}"

report() {
  echo "signing=$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "signing=$1" >> "$GITHUB_OUTPUT"
  fi
}

write_props() {
  {
    echo "storePassword=$1"
    echo "keyPassword=$2"
    echo "keyAlias=$3"
    echo "storeFile=release.jks"
  } > "$PROPS"
}

if [ -n "${KEYSTORE_BASE64:-}" ]; then
  : "${KEYSTORE_PASSWORD:?KEYSTORE_PASSWORD is required with KEYSTORE_BASE64}"
  echo "$KEYSTORE_BASE64" | base64 -d > "$JKS"
  write_props "$KEYSTORE_PASSWORD" "${KEY_PASSWORD:-$KEYSTORE_PASSWORD}" "$ALIAS"
  report external-keystore
  exit 0
fi

if [ -f "$ENC" ] && [ -n "${KEYSTORE_PASSWORD:-}" ]; then
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$ENC" -out "$JKS" -pass env:KEYSTORE_PASSWORD
  write_props "$KEYSTORE_PASSWORD" "$KEYSTORE_PASSWORD" "$ALIAS"
  report encrypted-keystore
  exit 0
fi

report none
