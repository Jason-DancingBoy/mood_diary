#!/bin/bash
# Apply local patches to pub-cache plugin sources after flutter pub get.
# Fix: "Reply already submitted" crash in image_cropper's onActivityResult

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache/hosted/pub.flutter-io.cn}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# image_cropper: guard against double-submitting MethodChannel.Result
for ver_dir in "$PUB_CACHE"/image_cropper-*/; do
  [ -d "$ver_dir" ] || continue
  dest="$ver_dir/android/src/main/java/vn/hunghd/flutter/plugins/imagecropper/ImageCropperDelegate.java"
  src="$SCRIPT_DIR/patches/image_cropper/vn/hunghd/flutter/plugins/imagecropper/ImageCropperDelegate.java"
  if [ -f "$src" ]; then
    cp "$src" "$dest"
    echo "[patch] Applied: $dest"
  fi
done
