#!/bin/sh
set -eu
if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [absolute-output-path.app]\n' "$0" >&2
    exit 2
fi
cd "$(dirname "$0")/.."
app_dir="${1:-$PWD/.build/DeskSway.app}"
case "$app_dir" in
    /*.app) ;;
    *) printf '%s\n' 'Output must be an absolute path ending in .app.' >&2; exit 2 ;;
esac
swift build -c release --product DeskSway
bin_dir=$(swift build -c release --show-bin-path)
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/DeskSway" "$app_dir/Contents/MacOS/DeskSway"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Sources/DeskSway/Resources/DeskSway.icns "$app_dir/Contents/Resources/DeskSway.icns"
cp -R "$bin_dir/DeskSway_DeskSway.bundle" "$app_dir/Contents/Resources/"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
# Local ad-hoc signature only: no personal identity, certificate or notarization.
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
# Updating files inside an existing bundle does not update its directory date.
# Refresh this app's registration so macOS picks up icon/Info.plist changes.
if [ "$#" -eq 0 ]; then
    touch "$app_dir"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app_dir"
fi
printf '%s\n' "$app_dir"
