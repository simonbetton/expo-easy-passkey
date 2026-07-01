#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SWIFT_DIR="packages/module/ios/generated"
KOTLIN_DIR="packages/module/android/src/main/java/expo/modules/easypasskey/generated"

mkdir -p "$TMP_DIR/$SWIFT_DIR" "$TMP_DIR/$KOTLIN_DIR"
cp -R "$ROOT_DIR/$SWIFT_DIR/." "$TMP_DIR/$SWIFT_DIR/"
cp -R "$ROOT_DIR/$KOTLIN_DIR/." "$TMP_DIR/$KOTLIN_DIR/"

bash "$ROOT_DIR/scripts/generate-bindings.sh"

diff -ru "$TMP_DIR/$SWIFT_DIR" "$ROOT_DIR/$SWIFT_DIR"
diff -ru "$TMP_DIR/$KOTLIN_DIR" "$ROOT_DIR/$KOTLIN_DIR"
