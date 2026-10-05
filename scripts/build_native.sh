#!/usr/bin/env bash
# One pinned runtime for local tests and every store artifact. No downloaded
# opaque .a/.so files and no local Apple signing/build pipeline.
set -euo pipefail
cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/native/runtime/target}"
root="$PWD"
manifest="$root/native/runtime/Cargo.toml"
# Keep C/C++ dependencies inside the Rust archive compatible with Runner's
# IPHONEOS_DEPLOYMENT_TARGET. Without this, clang defaults them to the SDK's
# newest iOS version, making a source-built archive unsuitable
# for the app's iOS 15.0 deployment target.
readonly IOS_DEPLOYMENT_TARGET=15.0
cd "$root/native/runtime"
case "${1:-}" in
  android|android-arm64)
    export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}/ndk/28.2.13676358}"
    test -d "$ANDROID_NDK_HOME" || { echo 'NDK 28.2.13676358 required' >&2; exit 1; }
    command -v cargo-ndk >/dev/null || cargo install cargo-ndk --version 4.1.2 --locked
    export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-Wl,-z,max-page-size=16384"
    rustup target add aarch64-linux-android
    cargo ndk -t arm64-v8a --platform 26 -o "$root/android/app/src/main/jniLibs" build --manifest-path "$manifest" --release --locked --features gpu
    if [[ "$1" == android ]]; then
      rustup target add x86_64-linux-android armv7-linux-androideabi
      cargo ndk -t x86_64 --platform 26 -o "$root/android/app/src/main/jniLibs" build --manifest-path "$manifest" --release --locked --features gpu
      cargo ndk -t armeabi-v7a --platform 26 -o "$root/android/app/src/main/jniLibs" build --manifest-path "$manifest" --release --locked
    fi
    ;;
  ios|ios-sim)
    export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
    if [[ "$1" == ios ]]; then target=aarch64-apple-ios; output=libcortiq_ffi.a
    else target=aarch64-apple-ios-sim; output=libcortiq_ffi_sim.a; fi
    rustup target add "$target"
    cargo build --manifest-path "$manifest" --target "$target" --release --locked --features gpu
    mkdir -p "$root/ios/Frameworks"
    cp "$CARGO_TARGET_DIR/$target/release/libcortiq_ffi.a" "$root/ios/Frameworks/$output"
    ;;
  *) echo 'Usage: scripts/build_native.sh android|android-arm64|ios|ios-sim' >&2; exit 2 ;;
esac
