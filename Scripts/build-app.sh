#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build/release"
app_dir="${1:-$project_dir/DuoBar.app}"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
minimum_os="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$project_dir/Resources/Info.plist")"

# Keep the linked SDK distinct from the deployment target so macOS enables
# the current SDK's appearance, including Liquid Glass.
swift build -c release --package-path "$project_dir" --sdk "$sdk_path" \
  -Xlinker -platform_version -Xlinker macos -Xlinker "$minimum_os" -Xlinker "$sdk_version"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/DuoBarOnMac" "$app_dir/Contents/MacOS/DuoBarOnMac"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp -R "$build_dir/DuoBarOnMac_DuoBarOnMac.bundle" "$app_dir/Contents/Resources/"

for localization_dir in "$project_dir"/Resources/*.lproj; do
  cp -R "$localization_dir" "$app_dir/Contents/Resources/"
done

# Finder metadata inherited from a synced Desktop folder can make codesign
# reject an otherwise valid local app bundle.
xattr -cr "$app_dir" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_dir/Contents/Resources/DuoBarOnMac_DuoBarOnMac.bundle" 2>/dev/null || true
xattr -d com.apple.fileprovider.fpfs#P "$app_dir/Contents/Resources/DuoBarOnMac_DuoBarOnMac.bundle" 2>/dev/null || true
codesign --force --deep --sign - --timestamp=none "$app_dir"
# The Desktop provider can reattach these directory-only attributes during
# the copy/sign step; remove them once more so codesign verification succeeds.
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -d com.apple.fileprovider.fpfs#P "$app_dir" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_dir/Contents/Resources/DuoBarOnMac_DuoBarOnMac.bundle" 2>/dev/null || true
xattr -d com.apple.fileprovider.fpfs#P "$app_dir/Contents/Resources/DuoBarOnMac_DuoBarOnMac.bundle" 2>/dev/null || true
codesign --verify --deep --strict "$app_dir"

echo "Built $app_dir"
