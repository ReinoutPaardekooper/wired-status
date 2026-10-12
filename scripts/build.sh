#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
cd "$project_root"
swift build -c release -Xswiftc -Osize -Xlinker -dead_strip
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_root/dist/WiredStatus.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/WiredStatus" "$app_dir/Contents/MacOS/WiredStatus"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
strip -x "$app_dir/Contents/MacOS/WiredStatus"
codesign --force --sign - "$app_dir"
printf '%s\n' "$app_dir"
