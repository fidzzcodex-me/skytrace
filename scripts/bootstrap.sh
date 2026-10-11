#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH" >&2
  exit 1
fi

if [ -f android/gradlew ] && [ -f android/gradle/wrapper/gradle-wrapper.jar ]; then
  echo "gradle wrapper already present"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

flutter create --platforms=android --org com.skytrace --project-name skytrace "$TMP/scaffold" >/dev/null

mkdir -p android/gradle/wrapper
cp "$TMP/scaffold/android/gradlew" android/gradlew
cp "$TMP/scaffold/android/gradlew.bat" android/gradlew.bat
cp "$TMP/scaffold/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
chmod +x android/gradlew

echo "gradle wrapper installed"
