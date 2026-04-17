// swift-tools-version: 5.9
// Swift package home: https://github.com/thebytearray/TagLib-spm
// TagLib C++ sources: upstream git submodule at `vendor/taglib` (https://github.com/taglib/taglib).
// After clone: `git submodule update --init --recursive` (pulls nested `3rdparty/utfcpp`).
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
            targets: ["TagLib"]
        ),
    ],
    dependencies: [
        // Swift-DocC: `swift package generate-documentation` and `preview-documentation` (local server).
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "TagLibCore",
            path: "vendor/taglib/taglib",
            publicHeadersPath: "spm_public_headers",
            cxxSettings: taglibCoreCXX,
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "CTagLib",
            dependencies: ["TagLibCore"],
            path: "Sources/CTagLib/Bridge",
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
            path: "Sources/TagLib"
        ),
        .testTarget(
            name: "TagLibTests",
            dependencies: ["TagLib"],
            path: "Tests/TagLibTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
