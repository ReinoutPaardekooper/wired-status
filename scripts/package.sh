#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
cd "$project_root"
./scripts/build.sh
arch_name="$(uname -m)"
ditto -c -k --sequesterRsrc --keepParent dist/WiredStatus.app "dist/WiredStatus-$arch_name.zip"
shasum -a 256 "dist/WiredStatus-$arch_name.zip" > "dist/WiredStatus-$arch_name.sha256"
printf '%s\n' "$project_root/dist/WiredStatus-$arch_name.zip"
