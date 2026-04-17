#!/usr/bin/env bash
# Build TagLib.xcframework for macOS, iOS, and iOS Simulator (requires dynamic library product in Package.swift).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:?output directory}"
mkdir -p "$OUT"

mkdir -p vendor/taglib/taglib/spm_public_headers

find_fw() {
  find "$1" -type d -name 'TagLib.framework' -path '*/Products/*' | head -1
}

rm -rf "${OUT:?}/macos.xcarchive" "${OUT}/ios.xcarchive" "${OUT}/sim.xcarchive" "${OUT}/TagLib.xcframework"

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

echo "Done: $OUT/TagLib.xcframework"
