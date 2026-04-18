#!/usr/bin/env bash
# Build TagLib.xcframework from the source Package.swift for macOS, iOS, and
# iOS Simulator, then zip it with `ditto` and compute its SHA-256. The release
# workflow feeds the zip + checksum into a binary `Package.swift` that's
# committed at the release tag.
#
# Usage: ./Scripts/create-xcframework.sh <output-dir>
# Outputs (under <output-dir>):
#   TagLib.xcframework/            - created by xcodebuild -create-xcframework
#   TagLib.xcframework.zip         - ditto-zipped archive (uploaded to the GitHub release)
#   TagLib.xcframework.zip.sha256  - single-line SHA-256 of the zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:?output directory}"
mkdir -p "$OUT"

mkdir -p vendor/taglib/taglib/spm_public_headers

find_fw() {
  find "$1" -type d -name 'TagLib.framework' -path '*/Products/*' | head -1
}

rm -rf "${OUT:?}/macos.xcarchive" "${OUT}/ios.xcarchive" "${OUT}/sim.xcarchive" \
       "${OUT}/TagLib.xcframework" "${OUT}/TagLib.xcframework.zip" "${OUT}/TagLib.xcframework.zip.sha256"

echo "Archiving macOS…"
xcodebuild -scheme TagLibSPM -destination 'generic/platform=macOS' \
  -archivePath "$OUT/macos.xcarchive" -derivedDataPath "$OUT/DerivedData-macos" \
  SKIP_INSTALL=NO archive

echo "Archiving iOS…"
xcodebuild -scheme TagLibSPM -destination 'generic/platform=iOS' \
  -archivePath "$OUT/ios.xcarchive" -derivedDataPath "$OUT/DerivedData-ios" \
  SKIP_INSTALL=NO archive

echo "Archiving iOS Simulator…"
xcodebuild -scheme TagLibSPM -destination 'generic/platform=iOS Simulator' \
  -archivePath "$OUT/sim.xcarchive" -derivedDataPath "$OUT/DerivedData-sim" \
  SKIP_INSTALL=NO archive

FW_MAC="$(find_fw "$OUT/macos.xcarchive")"
FW_IOS="$(find_fw "$OUT/ios.xcarchive")"
FW_SIM="$(find_fw "$OUT/sim.xcarchive")"

require_fw() {
  local name="$1" path="$2"
  if [[ -z "${path:-}" || ! -d "$path" ]]; then
    echo "error: could not locate TagLib.framework for $name (got: ${path:-empty})" >&2
    exit 1
  fi
}

require_fw macOS "$FW_MAC"
require_fw iOS "$FW_IOS"
require_fw "iOS Simulator" "$FW_SIM"

echo "Creating XCFramework…"
xcodebuild -create-xcframework \
  -framework "$FW_MAC" \
  -framework "$FW_IOS" \
  -framework "$FW_SIM" \
  -output "$OUT/TagLib.xcframework"

echo "Zipping XCFramework with ditto (preserves framework symlinks)…"
# Plain `zip -r` mangles framework Versions/Current symlinks which breaks
# loading the .xcframework on consumer machines. `ditto` is what
# ffmpeg-kit-spm uses and what Xcode produces internally.
ditto -c -k --sequesterRsrc --keepParent \
  "$OUT/TagLib.xcframework" \
  "$OUT/TagLib.xcframework.zip"

CHECKSUM="$(shasum -a 256 "$OUT/TagLib.xcframework.zip" | awk '{ print $1 }')"
printf '%s\n' "$CHECKSUM" > "$OUT/TagLib.xcframework.zip.sha256"

echo "Done: $OUT/TagLib.xcframework"
echo "Zip:      $OUT/TagLib.xcframework.zip"
echo "SHA-256:  $CHECKSUM"
