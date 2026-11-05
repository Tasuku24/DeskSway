#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product DeskSway
bin_dir=$(swift build -c release --show-bin-path)
app_dir="$PWD/.build/DeskSway.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/DeskSway" "$app_dir/Contents/MacOS/DeskSway"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Sources/DeskSway/Resources/DeskSway.icns "$app_dir/Contents/Resources/DeskSway.icns"
cp -R "$bin_dir/DeskSway_DeskSway.bundle" "$app_dir/Contents/Resources/"
# Local ad-hoc signature only: no personal identity, certificate or notarization.
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
# Updating files inside an existing bundle does not update its directory date.
# Refresh this app's registration so macOS picks up icon/Info.plist changes.
touch "$app_dir"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app_dir"
printf '%s\n' "$app_dir"
