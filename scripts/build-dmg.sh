#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
bash "$project_dir/scripts/build-app.sh"

app_dir="$project_dir/dist/Slam.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
dmg_path="$project_dir/dist/Slam-$version.dmg"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/slam-dmg.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

ditto "$app_dir" "$staging_dir/Slam.app"
ln -s /Applications "$staging_dir/Applications"
cat > "$staging_dir/Install.txt" <<'EOF'
Install Slam

1. Drag Slam.app to Applications, then eject this disk image.
2. Open Slam from Applications.
3. This community build is ad-hoc signed, not Apple-notarized. If macOS
   blocks it, open System Settings > Privacy & Security and choose Open Anyway
   for Slam, then confirm. This option may be restricted on managed Macs.
4. Enable Slam in System Settings > Privacy & Security > Accessibility.
5. Open Slack and enable its Dock badge in Slack's notification preferences.

Slam requires macOS 13 or later and supports Apple Silicon and Intel Macs.
It reads Slack's Dock badge, not your messages. A ? means the badge could
not be read; right-click the menu bar item for Accessibility Setup.

For updates, quit Slam before replacing the installed app. If badge reading
stops afterward, remove and re-add Slam in Accessibility, then relaunch.
EOF

hdiutil create -volname "Slam $version" -srcfolder "$staging_dir" \
    -format UDZO -ov "$dmg_path"
hdiutil verify "$dmg_path"
cd "$project_dir/dist"
shasum -a 256 "Slam-$version.dmg" > "Slam-$version.dmg.sha256"
printf 'Created %s\n' "$dmg_path"
