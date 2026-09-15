#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build/release"
app_dir="$project_dir/DuoBar.app"

swift build -c release --package-path "$project_dir"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/DuoBarOnMac" "$app_dir/Contents/MacOS/DuoBarOnMac"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

# Finder metadata inherited from a synced Desktop folder can make codesign
# reject an otherwise valid local app bundle.
xattr -cr "$app_dir" 2>/dev/null || true
codesign --force --deep --sign - --timestamp=none "$app_dir"
# The Desktop provider can reattach these directory-only attributes during
# the copy/sign step; remove them once more so codesign verification succeeds.
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -d com.apple.fileprovider.fpfs#P "$app_dir" 2>/dev/null || true
codesign --verify --deep --strict "$app_dir"

echo "Built $app_dir"
