// swift-tools-version: 5.9
// Binary SPM distribution for TagLib.
//
// The consumer-facing manifest. It points at a prebuilt `TagLib.xcframework.zip`
// attached to a GitHub release. Both `release` and `checksum` below are
// rewritten by `.github/workflows/release.yml` each time a new tag is cut, so
// every tag resolves to the matching zip. If you're hacking on the native
// sources, use `BuildPackage/Package.swift` instead — that's where the C++
// targets + tests live.
import PackageDescription

let release = "v0.0.0"
let checksum = "0000000000000000000000000000000000000000000000000000000000000000"

let package = Package(
    name: "TagLibSPM",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "TagLib",
            targets: ["TagLib"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "TagLib",
            url: "https://github.com/thebytearray/TagLib-spm/releases/download/\(release)/TagLib.xcframework.zip",
            checksum: checksum
        ),
    ]
)
