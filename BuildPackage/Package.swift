// swift-tools-version: 5.9
// Source build manifest for TagLibSPM.
//
// This manifest compiles TagLib directly from the git submodule under
// `../vendor/taglib`. It is NOT the manifest SPM consumers resolve — the
// consumer manifest lives at the repository root (`../Package.swift`) and
// points at a prebuilt `TagLib.xcframework.zip` from a GitHub release.
//
// Use this manifest for:
//   - local development of the C++ sources / Swift bridge
//   - running `swift test`
//   - producing the XCFramework via `../Scripts/create-xcframework.sh`
//
// All `path:` values are prefixed with `../` because this Package.swift lives
// one directory below the repo root. Header search paths are target-relative
// (i.e. relative to the resolved filesystem path of the target), so they are
// unchanged from the original root manifest.
//
// After clone: `git submodule update --init --recursive` (from the repo root).
import PackageDescription

/// Header search paths under `vendor/taglib/taglib` (official TagLib sources from git submodule).
private let taglibInnerIncludeSubdirs: [String] = [
    "toolkit",
    "mpeg",
    "mpeg/id3v2",
    "mpeg/id3v2/frames",
    "mpeg/id3v1",
    "asf",
    "ogg",
    "ogg/flac",
    "flac",
    "ogg/vorbis",
    "ogg/speex",
    "ogg/opus",
    "mpc",
    "ape",
    "wavpack",
    "mp4",
    "trueaudio",
    "riff",
    "riff/aiff",
    "riff/wav",
    "mod",
    "s3m",
    "it",
    "xm",
    "dsf",
    "dsdiff",
    "shorten",
]

private let taglibCoreCXX: [CXXSetting] = {
    var s: [CXXSetting] = [ .headerSearchPath(".") ]
    s.append(contentsOf: taglibInnerIncludeSubdirs.map { .headerSearchPath($0) })
    s.append(contentsOf: [
        .headerSearchPath("../../../Sources/CTagLib/_spm_config"),
        .headerSearchPath("../3rdparty/utfcpp/source"),
        .define("HAVE_CONFIG_H"),
        .define("TAGLIB_STATIC"),
    ])
    return s
}()

private let bridgeCXX: [CXXSetting] = {
    var s: [CXXSetting] = taglibInnerIncludeSubdirs.map {
        .headerSearchPath("../../../vendor/taglib/taglib/\($0)")
    }
    s.append(contentsOf: [
        .headerSearchPath("../../../vendor/taglib/taglib"),
        .headerSearchPath("../_spm_config"),
        .headerSearchPath("../../../vendor/taglib/3rdparty/utfcpp/source"),
        .define("HAVE_CONFIG_H"),
        .define("TAGLIB_STATIC"),
    ])
    return s
}()

let package = Package(
    name: "TagLibSPM",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "TagLib",
            type: .dynamic,
            targets: ["TagLib"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "TagLibCore",
            path: "../vendor/taglib/taglib",
            publicHeadersPath: "spm_public_headers",
            cxxSettings: taglibCoreCXX,
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "CTagLib",
            dependencies: ["TagLibCore"],
            path: "../Sources/CTagLib/Bridge",
            sources: ["taglib_swift_bridge.cpp"],
            publicHeadersPath: "include",
            cxxSettings: bridgeCXX,
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "TagLib",
            dependencies: ["CTagLib"],
            path: "../Sources/TagLib"
        ),
        .testTarget(
            name: "TagLibTests",
            dependencies: ["TagLib"],
            path: "../Tests/TagLibTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
