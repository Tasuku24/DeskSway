#!/bin/sh
set -eu
if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [version, e.g. 0.1.0-beta.1]\n' "$0" >&2
    exit 2
fi
cd "$(dirname "$0")/.."
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
release_version="${1:-$app_version}"
case "$release_version" in
    ''|*[!A-Za-z0-9.-]*) printf '%s\n' 'Invalid release version.' >&2; exit 2 ;;
esac
case "$release_version" in
    "$app_version"|"$app_version"-*) ;;
    *) printf 'Release version must match app version %s.\n' "$app_version" >&2; exit 2 ;;
esac

mkdir -p .build/releases
staging=$(mktemp -d "$PWD/.build/release-staging.XXXXXX")
payload="$staging/DeskSway-$release_version"
mkdir "$payload"
# Build separately so packaging never overwrites or registers the running app.
./scripts/build-app.sh "$payload/DeskSway.app"
architecture=$(lipo -archs "$payload/DeskSway.app/Contents/MacOS/DeskSway")
case "$architecture" in
    arm64|x86_64) ;;
    *) printf 'Unsupported release architecture: %s\n' "$architecture" >&2; exit 1 ;;
esac
archive="DeskSway-$release_version-macos-$architecture.zip"
if [ -e ".build/releases/$archive" ] || [ -e ".build/releases/$archive.sha256" ]; then
    printf 'Release asset already exists: %s\n' "$archive" >&2
    exit 1
fi
cp LICENSE "$payload/LICENSE"
cp docs/installation.md "$payload/INSTALL.md"
codesign --verify --deep --strict "$payload/DeskSway.app"
ditto -c -k --sequesterRsrc --keepParent "$payload" "$staging/$archive"
# An atomic link fails if another packaging process has created this asset.
ln "$staging/$archive" ".build/releases/$archive"
(cd .build/releases && shasum -a 256 "$archive" > "$archive.sha256")
printf 'Release assets:\n%s\n%s\n' "$PWD/.build/releases/$archive" "$PWD/.build/releases/$archive.sha256"
