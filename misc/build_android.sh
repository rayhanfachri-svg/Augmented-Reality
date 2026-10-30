#!/usr/bin/env bash
# build_android.sh — bantu build GDNative libgdopencvexample.so untuk Android arm64-v8a.
# SEMUA toolchain harus sudah terpasang & di-path DULU (lihat IMPLEMENTATION_EXPORD.MD §1):
#   JDK, Android SDK/NDK, OpenCV Android SDK, godot-cpp static lib untuk android.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# --- 1. Validasi env build Android (semua HARUS ada sebelum build) ---
fail=0
for var in JAVA_HOME ANDROID_NDK_HOME OPENCV_ANDROID_SDK; do
  if [ -z "${!var:-}" ]; then echo "❌ \$$var belum diset."; fail=1; fi
done
if [ ! -f "godot-cpp/bin/libgodot-cpp.android.release.64.a" ]; then
  echo "❌ godot-cpp Android static lib belum dibuild di godot-cpp/bin/."; fail=1
fi
if [ "$fail" -eq 1 ]; then
  echo "❌ Toolchain Android belum siap — instal dulu (lihat IMPLEMENTATION_EXPORD.MD §1), lalu re-run."
  exit 1
fi

# --- 2. Build libgdopencvexample.so untuk Android ---
echo "🚀 Build GDNative → demo/bin/android/arm64-v8a/libgdopencvexample.so"
scons platform=android android_abi=arm64-v8a android_api=21 \
  target=release -j"$(nproc)"

OUT="demo/bin/android/arm64-v8a/libgdopencvexample.so"
if [ -f "$OUT" ]; then
  echo "✅ Berhasil: $OUT"
  echo "   Next: buka demo di Godot editor → Project → Export → Android → Export Project"
else
  echo "❌ .so tidak dihasilkan — periksa log scons di atas."
  exit 1
fi
