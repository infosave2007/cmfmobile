#!/usr/bin/env bash
# Package the NPU lane for Android arm64: build the cortiq-npu shim and copy
# the QNN HTP runtime next to libcortiq_ffi.so.
#
#   QAIRT_SDK_ROOT   Qualcomm AI Runtime SDK (Community edition), the directory
#                    holding include/ and lib/. Its licence allows the object
#                    code to ship inside an application, not on its own.
#   CORTIQ_NPU_SRC   optional: cortiq_npu.cpp (default: the engine checkout
#                    cargo fetched for native/runtime).
#
# Without QAIRT_SDK_ROOT nothing is packaged and the app's NPU switch reports
# that the backend is unavailable; everything else works as before.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/android/app/src/main/jniLibs/arm64-v8a"
sdk="${QAIRT_SDK_ROOT:-}"
if [[ -z "$sdk" || ! -d "$sdk/lib/aarch64-android" ]]; then
  echo "fetch_npu_libs: QAIRT_SDK_ROOT not set or not an SDK; NPU lane not packaged" >&2
  exit 0
fi
ndk="${ANDROID_NDK_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}/ndk/28.2.13676358}"
host="$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)"
cxx="$ndk/toolchains/llvm/prebuilt/$host/bin/aarch64-linux-android26-clang++"
src="${CORTIQ_NPU_SRC:-}"
if [[ -z "$src" ]]; then
  (cd "$root/native/runtime" && cargo fetch --locked >/dev/null 2>&1 || true)
  src="$(find "${CARGO_HOME:-$HOME/.cargo}/git/checkouts" -path '*crates/cortiq-engine/npu/cortiq_npu.cpp' 2>/dev/null | head -1)"
fi
test -f "$src" || { echo "fetch_npu_libs: cortiq_npu.cpp not found (set CORTIQ_NPU_SRC)" >&2; exit 1; }
mkdir -p "$out"
"$cxx" -O2 -std=c++17 -fPIC -shared -I "$sdk/include/QNN" -o "$out/libcortiq_npu.so" "$src" \
  -ldl -static-libstdc++ -Wl,-z,max-page-size=16384
# The backend, the on-device graph preparer and the system library.
for f in libQnnHtp.so libQnnHtpPrepare.so libQnnSystem.so; do
  cp "$sdk/lib/aarch64-android/$f" "$out/"
done
# One stub (ARM side) and one skeleton (DSP side) per Hexagon generation.
n=0
for v in 68 69 73 75 79 81 85; do
  stub="$sdk/lib/aarch64-android/libQnnHtpV${v}Stub.so"
  skel="$sdk/lib/hexagon-v${v}/unsigned/libQnnHtpV${v}Skel.so"
  [[ -f "$stub" && -f "$skel" ]] || continue
  cp "$stub" "$skel" "$out/"
  [[ -f "$sdk/lib/hexagon-v${v}/unsigned/libQnnHtpV${v}.so" ]] && cp "$sdk/lib/hexagon-v${v}/unsigned/libQnnHtpV${v}.so" "$out/"
  n=$((n + 1))
done
echo "fetch_npu_libs: shim + QNN HTP for $n Hexagon generation(s) in $out ($(du -sh "$out" | cut -f1))"
