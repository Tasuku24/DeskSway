#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product DeskSway
bin_dir=$(swift build -c release --show-bin-path)
app_dir="$PWD/.build/DeskSway.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/DeskSway" "$app_dir/Contents/MacOS/DeskSway"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
# Local ad-hoc signature only: no personal identity, certificate or notarization.
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf '%s\n' "$app_dir"
