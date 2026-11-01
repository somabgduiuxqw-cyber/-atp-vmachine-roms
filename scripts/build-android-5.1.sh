
#!/usr/bin/env bash
set -euo pipefail

ANDROID_VERSION="5.1"
ANDROID_BRANCH="android-5.1.1_r38"
ANDROID_TARGET="aosp_arm64-eng"

ROOT="$PWD"
SOURCE="$ROOT/aosp-android-5.1"
OUT="$SOURCE/out/target/product/generic_arm64"

echo "Starting Android 5.1 ARM64 source build"

if ! command -v repo >/dev/null 2>&1; then
    echo "ERROR: repo tool is missing."
    exit 1
fi

if ! command -v java >/dev/null 2>&1; then
    echo "ERROR: Java is missing."
    exit 1
fi

mkdir -p "$SOURCE"
cd "$SOURCE"

if [ ! -d .repo ]; then
    repo init \
      -u https://android.googlesource.com/platform/manifest \
      -b "$ANDROID_BRANCH"
fi

repo sync -c -j8

source build/envsetup.sh
lunch "$ANDROID_TARGET"

make -j"$(nproc)" bootimage systemimage userdataimage

if [ ! -f "$OUT/boot.img" ]; then
    echo "ERROR: Android build did not produce boot.img"
    exit 1
fi

if [ ! -f "$OUT/system.img" ]; then
    echo "ERROR: Android build did not produce system.img"
    exit 1
fi

mkdir -p "$ROOT/dist/rom-files"

find "$OUT" -maxdepth 1 -type f \
  \( -name "*.img" -o -name "kernel*" \) \
  -exec cp {} "$ROOT/dist/rom-files/" \;

python3 - "$ROOT/dist/rom-files" <<'PY'
import json
import os
import sys

directory = sys.argv[1]

manifest = {
    "name": "ATP VMachine Android 5.1",
    "android_version": "5.1",
    "architecture": "arm64",
    "build_target": "aosp_arm64-eng",
    "files": sorted(os.listdir(directory))
}

with open(os.path.join(directory, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
PY

cd "$ROOT/dist"

zip -r atp-android-5.1-arm64.zip rom-files

echo "Android 5.1 build
packaging completed."
