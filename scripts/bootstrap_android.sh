#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
flutter create --platforms=android --org com.upc --project-name upc "$TMP/template"
# Use the official Flutter-generated wrapper binary; never substitute a fake JAR.
cp "$TMP/template/android/gradle/wrapper/gradle-wrapper.jar" "$ROOT/android/gradle/wrapper/gradle-wrapper.jar"
# Official scripts preserve OS-specific Java handling.
cp "$TMP/template/android/gradlew" "$ROOT/android/gradlew"
cp "$TMP/template/android/gradlew.bat" "$ROOT/android/gradlew.bat"
chmod +x "$ROOT/android/gradlew"
# The project files, application ID, manifest and dependencies are NOT overwritten.
