#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
cd "$project_root"
swift build -c release --disable-local-rpath -Xswiftc -no-toolchain-stdlib-rpath -Xswiftc -Osize -Xlinker -dead_strip
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_root/dist/WiredStatus.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/WiredStatus" "$app_dir/Contents/MacOS/WiredStatus"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
strip -x "$app_dir/Contents/MacOS/WiredStatus"
# Some SDKs inject a toolchain search path even with the driver flags above.
# This app loads only macOS-provided frameworks and the system Swift runtime.
while IFS= read -r runtime_path; do
    case "$runtime_path" in
        /usr/lib/swift) ;;
        *) install_name_tool -delete_rpath "$runtime_path" "$app_dir/Contents/MacOS/WiredStatus" ;;
    esac
done < <(otool -l "$app_dir/Contents/MacOS/WiredStatus" | awk '
    $1 == "cmd" { rpath = ($2 == "LC_RPATH") }
    rpath && $1 == "path" {
        sub(/^[[:space:]]*path[[:space:]]+/, "")
        sub(/[[:space:]]+\(offset [0-9]+\)$/, "")
        print
    }')
codesign --force --sign - "$app_dir"
printf '%s\n' "$app_dir"
