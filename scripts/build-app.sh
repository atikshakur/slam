#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-module-cache"
swift_options=(--cache-path "$project_dir/.build/spm-cache")
# Set only in environments that cannot launch SwiftPM's nested build sandbox.
if [[ "${SLAM_DISABLE_BUILD_SANDBOX:-0}" == "1" ]]; then
    swift_options+=(--disable-sandbox)
fi
app_dir="$project_dir/dist/Slam.app"
mkdir -p "$app_dir/Contents/MacOS"
# Build each architecture separately so full Xcode is not required, then
# combine them into one universal binary for Apple Silicon and Intel.
binaries=()
for architecture in arm64 x86_64; do
    arch_options=("${swift_options[@]}" --triple "$architecture-apple-macosx13.0"
                  --scratch-path "$project_dir/.build/$architecture")
    swift build "${arch_options[@]}" --configuration release --product Slam
    binary_dir="$(swift build "${arch_options[@]}" --configuration release --show-bin-path)"
    binaries+=("$binary_dir/Slam")
done
lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/Slam"
cp "$project_dir/scripts/Info.plist" "$app_dir/Contents/Info.plist"
# Local ad-hoc signing; this is not a Developer ID distribution signature.
# A stable identifier and fixed installation path help macOS identify the app.
codesign --force --sign - --identifier local.slam.app "$app_dir"
codesign --verify --strict "$app_dir"
printf 'Built %s\n' "$app_dir"
